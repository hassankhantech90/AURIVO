import { EmailOutcome } from "./queue.ts";

// Minimal Resend client (https://resend.com/docs/api-reference/emails/send-email).
// The API key is the RESEND_API_KEY secret and is never logged.

export interface SendResult {
  httpStatus: number;
  providerId: string | null;
  errorName: string | null;
}

export async function sendEmail(
  apiKey: string,
  msg: { from: string; to: string; subject: string; html: string; text: string; replyTo?: string },
  idempotencyKey: string,
): Promise<SendResult> {
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        // Resend de-duplicates retries of the same outbox row for 24h.
        "Idempotency-Key": idempotencyKey,
      },
      body: JSON.stringify({
        from: msg.from,
        to: [msg.to],
        subject: msg.subject,
        html: msg.html,
        text: msg.text,
        ...(msg.replyTo ? { reply_to: msg.replyTo } : {}),
      }),
    });
    // deno-lint-ignore no-explicit-any
    const body: any = await res.json().catch(() => ({}));
    return {
      httpStatus: res.status,
      providerId: typeof body?.id === "string" ? body.id : null,
      errorName: typeof body?.name === "string" ? body.name : null,
    };
  } catch {
    return { httpStatus: 0, providerId: null, errorName: "network_error" };
  }
}

// 2xx -> sent. 422/400 (invalid address / payload) -> rejected (permanent).
// 401/403 (bad key / unverified domain), 429 and 5xx/network -> transient, so
// a config mistake doesn't burn messages; the DB backoff caps retries.
export function classify(r: SendResult): EmailOutcome {
  if (r.httpStatus >= 200 && r.httpStatus < 300) return "sent";
  if (r.httpStatus === 400 || r.httpStatus === 422) return "rejected";
  return "transient";
}
