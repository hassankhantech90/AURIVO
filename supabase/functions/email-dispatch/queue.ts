import postgres from "postgres";

// DB access for the worker. Connects as the least-privilege
// email_dispatch_worker role (migration 51) through the Supavisor TRANSACTION
// pooler. The full connection string is the EMAIL_WORKER_DB_URL secret and is
// never logged. The role can only EXECUTE the three worker RPCs.

export interface ClaimedEmail {
  outbox_id: string;
  claim_id: string;
  notification_id: string;
  to: string;
  name: string | null;
  type: string;
  subject: string;
  body: string;
  route: string | null;
  event: string | null;
}

export type EmailOutcome = "sent" | "rejected" | "transient";

const sql = postgres(Deno.env.get("EMAIL_WORKER_DB_URL") ?? "", {
  prepare: false,
  max: 2,
  idle_timeout: 20,
});

export async function requeueStale(graceSeconds = 0): Promise<number> {
  const rows = await sql<{ n: number }[]>`select public.requeue_stale_email(${graceSeconds}) as n`;
  return rows[0]?.n ?? 0;
}

export async function claim(batch = 25, leaseSeconds = 120): Promise<ClaimedEmail[]> {
  const rows = await sql<{ res: ClaimedEmail[] | null }[]>`
    select public.claim_email_outbox(${batch}, ${leaseSeconds}) as res`;
  return rows[0]?.res ?? [];
}

export async function report(
  outboxId: string,
  claimId: string,
  outcome: EmailOutcome,
  providerId: string | null,
): Promise<boolean> {
  const rows = await sql<{ ok: boolean }[]>`
    select public.report_email_result(${outboxId}::uuid, ${claimId}::uuid, ${outcome}, ${providerId}) as ok`;
  return rows[0]?.ok ?? false;
}
