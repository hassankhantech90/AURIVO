import { claim, report, requeueStale } from "./queue.ts";
import { render } from "./render.ts";
import { classify, sendEmail } from "./resend.ts";

// email-dispatch worker (migration 51). Invoked once per minute by pg_cron ->
// pg_net with a Bearer CRON_SECRET (verify_jwt = false; the function validates
// the secret itself) — the same pattern as push-dispatch. Each invocation:
// requeue stale -> claim -> render -> Resend -> report, until empty or ~50s.
//
// Secrets: CRON_SECRET, EMAIL_WORKER_DB_URL, RESEND_API_KEY,
// EMAIL_FROM (e.g. "Pareezay.Hub <orders@yourdomain.pk>"), optional
// EMAIL_REPLY_TO and APP_URL (base for deep links). See docs/EMAIL_SETUP.md.
//
// Logs carry only safe metadata (ids, http status, outcome, counts). NEVER the
// recipient address, body, API key, DSN or Authorization header.

const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const EMAIL_FROM = Deno.env.get("EMAIL_FROM") ?? "";
const EMAIL_REPLY_TO = Deno.env.get("EMAIL_REPLY_TO") ?? undefined;
const APP_URL = Deno.env.get("APP_URL") ?? "";
const TIME_BUDGET_MS = 50_000;

function log(fields: Record<string, unknown>): void {
  console.log(JSON.stringify(fields));
}

function timingSafeEqual(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  if (ea.length !== eb.length) return false;
  let diff = 0;
  for (let i = 0; i < ea.length; i++) diff |= ea[i] ^ eb[i];
  return diff === 0;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  const auth = req.headers.get("Authorization") ?? "";
  if (!CRON_SECRET || !timingSafeEqual(auth, `Bearer ${CRON_SECRET}`)) {
    return json({ error: "unauthorized" }, 401);
  }
  if (!RESEND_API_KEY || !EMAIL_FROM) {
    // Misconfigured: leave the queue untouched rather than burning attempts.
    log({ evt: "config_missing" });
    return json({ ok: false, error: "not_configured" }, 503);
  }

  const started = Date.now();
  let claimed = 0;
  let sent = 0;

  try {
    await requeueStale(0);
    while (Date.now() - started < TIME_BUDGET_MS) {
      const rows = await claim(25, 120);
      if (rows.length === 0) break;
      claimed += rows.length;
      for (const row of rows) {
        const { subject, html, text } = render(row, APP_URL);
        const res = await sendEmail(
          RESEND_API_KEY,
          { from: EMAIL_FROM, to: row.to, subject, html, text, replyTo: EMAIL_REPLY_TO },
          row.outbox_id,
        );
        const outcome = classify(res);
        if (outcome === "sent") sent++;
        log({
          evt: "email_send_result",
          outbox_id: row.outbox_id,
          type: row.type,
          http: res.httpStatus,
          error: res.errorName,
          outcome,
        });
        const ok = await report(row.outbox_id, row.claim_id, outcome, res.providerId);
        if (!ok) log({ evt: "report_rejected", outbox_id: row.outbox_id });
        if (Date.now() - started >= TIME_BUDGET_MS) break;
      }
    }
    log({ evt: "drain_done", claimed, sent, elapsed_ms: Date.now() - started });
    return json({ ok: true, claimed, sent });
  } catch (e) {
    const name = e instanceof Error ? e.name : "unknown";
    const code = (e as { code?: unknown })?.code;
    log({ evt: "dispatch_error", name, code: code == null ? null : String(code) });
    return json({ ok: false }, 500);
  }
});
