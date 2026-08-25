import { classify, getAccessToken, sendToDevice } from "./fcm.ts";
import { buildMessage } from "./payload.ts";
import { claim, report, requeueStale } from "./queue.ts";
import { ClaimedRow, DeviceResult } from "./types.ts";

// push-dispatch worker. Invoked once per minute by pg_cron -> pg_net with a
// Bearer CRON_SECRET (verify_jwt = false; the function validates the secret
// itself). Each invocation: requeue stale -> drain the outbox (claim -> FCM v1
// send per device -> report) until empty or a ~50s time budget. Push failures
// never touch the canonical notification or its read state; the DB owns the
// retry/backoff/dead/dedup state machine.
//
// Diagnostics: each pipeline stage emits sanitized structured logs
// (evt=stage/stage_error/...). Only safe metadata is logged — stage name, error
// runtime name + code (postgres.js SQLSTATE / errno), FCM http/errorCode, ids,
// counts, elapsed ms. NEVER the DSN, DB password, CRON_SECRET, Authorization,
// FCM token, service-account JSON/key, OAuth token, or notification body.

const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") ?? "";
const VALIDATE_ONLY = (Deno.env.get("PUSH_VALIDATE_ONLY") ?? "false") === "true";
const TIME_BUDGET_MS = 50_000;

// deno-lint-ignore no-explicit-any
type ServiceAccount = any;

function serviceAccount(): ServiceAccount {
  return JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");
}

function log(fields: Record<string, unknown>): void {
  // Allowed fields only — never token / body / secret / OAuth token / DSN.
  console.log(JSON.stringify(fields));
}

// Extract ONLY safe, non-sensitive error metadata: the runtime name and, when
// present, a code (postgres.js PostgresError.code = SQLSTATE; connection errors
// carry an errno-style code). NEVER include error.message — postgres.js may
// embed the connection string / host there.
function safeErr(e: unknown): { name: string; code: string | null } {
  if (e && typeof e === "object") {
    const name = e instanceof Error ? e.name : "unknown";
    const code = (e as { code?: unknown }).code;
    return { name, code: code == null ? null : String(code) };
  }
  return { name: "unknown", code: null };
}

// Runs a pipeline stage with start/ok logs, and on failure a sanitized
// stage_error, then rethrows so the caller still returns a generic 500.
async function stage<T>(
  name: string,
  fn: () => Promise<T>,
  extra: Record<string, unknown> = {},
): Promise<T> {
  log({ evt: "stage", stage: `${name}_start`, ...extra });
  try {
    const out = await fn();
    log({ evt: "stage", stage: `${name}_ok`, ...extra });
    return out;
  } catch (e) {
    const { name: errName, code } = safeErr(e);
    log({ evt: "stage_error", stage: name, error_name: errName, code, ...extra });
    throw e;
  }
}

// Constant-time string comparison for the CRON_SECRET bearer check, to avoid a
// timing side-channel on the shared secret.
function timingSafeEqual(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  if (ea.length !== eb.length) return false;
  let diff = 0;
  for (let i = 0; i < ea.length; i++) diff |= ea[i] ^ eb[i];
  return diff === 0;
}

async function processRow(row: ClaimedRow, sa: ServiceAccount): Promise<void> {
  let token = await stage("fcm_oauth", () => getAccessToken(sa), {
    outbox_id: row.outbox_id,
  });
  const results: DeviceResult[] = [];

  for (const dev of row.devices) {
    const message = buildMessage(row, dev.token);
    log({
      evt: "stage",
      stage: "fcm_send_start",
      outbox_id: row.outbox_id,
      device_id: dev.device_id,
    });
    let send = await sendToDevice(token, FCM_PROJECT_ID, message, VALIDATE_ONLY);
    let outcome = classify(send);

    if (outcome === "unauthorized") {
      token = await stage("fcm_oauth", () => getAccessToken(sa, true), {
        outbox_id: row.outbox_id,
      });
      send = await sendToDevice(token, FCM_PROJECT_ID, message, VALIDATE_ONLY);
      outcome = classify(send);
      if (outcome === "unauthorized") outcome = "transient";
    }

    log({
      evt: "fcm_send_result",
      outbox_id: row.outbox_id,
      notification_id: row.notification_id,
      device_id: dev.device_id,
      platform: dev.platform,
      http: send.httpStatus,
      code: send.errorCode ?? null,
      outcome,
    });
    results.push({ device_id: dev.device_id, outcome });
  }

  // Report the exact full claimed device set; the DB RPC rejects anything else.
  const ok = await stage(
    "report",
    () => report(row.outbox_id, row.claim_id, results),
    { outbox_id: row.outbox_id },
  );
  if (!ok) log({ evt: "report_rejected", outbox_id: row.outbox_id });
}

Deno.serve(async (req: Request): Promise<Response> => {
  const auth = req.headers.get("Authorization") ?? "";
  if (!CRON_SECRET || !timingSafeEqual(auth, `Bearer ${CRON_SECRET}`)) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  log({ evt: "stage", stage: "auth_ok" });

  const started = Date.now();
  let claimed = 0;
  let processed = 0;

  try {
    const sa = await stage("sa_parse", () => Promise.resolve(serviceAccount()));

    await stage("db_requeue", () => requeueStale(0));

    while (Date.now() - started < TIME_BUDGET_MS) {
      const rows = await stage("db_claim", () => claim(50, 120), {
        claimed_so_far: claimed,
      });
      if (rows.length === 0) break;
      claimed += rows.length;
      for (const row of rows) {
        await processRow(row, sa);
        processed++;
        if (Date.now() - started >= TIME_BUDGET_MS) break;
      }
    }

    log({
      evt: "drain_done",
      claimed,
      processed,
      elapsed_ms: Date.now() - started,
      validateOnly: VALIDATE_ONLY,
    });
    return new Response(
      JSON.stringify({ ok: true, claimed, processed, validateOnly: VALIDATE_ONLY }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    // Top-level 500 stays generic to the caller; the sanitized stage_error above
    // already identified where it failed.
    const { name, code } = safeErr(e);
    log({ evt: "dispatch_error", name, code, elapsed_ms: Date.now() - started });
    return new Response(JSON.stringify({ ok: false }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
