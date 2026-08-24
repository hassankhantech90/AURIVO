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
  // Allowed fields only — never token / body / secret / OAuth token.
  console.log(JSON.stringify(fields));
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
  let token = await getAccessToken(sa);
  const results: DeviceResult[] = [];

  for (const dev of row.devices) {
    const message = buildMessage(row, dev.token);
    let send = await sendToDevice(token, FCM_PROJECT_ID, message, VALIDATE_ONLY);
    let outcome = classify(send);

    if (outcome === "unauthorized") {
      token = await getAccessToken(sa, true); // refresh once
      send = await sendToDevice(token, FCM_PROJECT_ID, message, VALIDATE_ONLY);
      outcome = classify(send);
      if (outcome === "unauthorized") outcome = "transient";
    }

    log({
      evt: "fcm_send",
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
  const ok = await report(row.outbox_id, row.claim_id, results);
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

  const started = Date.now();
  const sa = serviceAccount();
  let claimed = 0;
  let processed = 0;

  try {
    await requeueStale(0);
    while (Date.now() - started < TIME_BUDGET_MS) {
      const rows = await claim(50, 120);
      if (rows.length === 0) break;
      claimed += rows.length;
      for (const row of rows) {
        await processRow(row, sa);
        processed++;
        if (Date.now() - started >= TIME_BUDGET_MS) break;
      }
    }
    return new Response(JSON.stringify({ ok: true, claimed, processed, validateOnly: VALIDATE_ONLY }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    // Never log raw error text (may contain the DB connection string).
    log({ evt: "dispatch_error", name: e instanceof Error ? e.name : "unknown" });
    return new Response(JSON.stringify({ ok: false }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
