import postgres from "postgres";
import { ClaimedRow, DeviceResult } from "./types.ts";

// DB access for the worker. Connects as the least-privilege push_dispatch_worker
// role (migration 25) through the Supavisor TRANSACTION pooler. The full
// connection string is provided as the PUSH_WORKER_DB_URL secret and is never
// logged. Prepared statements are disabled (transaction-mode pooling). The role
// can only EXECUTE the three worker RPCs — it has no table access — so every
// query below is an RPC call.

const sql = postgres(Deno.env.get("PUSH_WORKER_DB_URL") ?? "", {
  prepare: false,
  max: 2,
  idle_timeout: 20,
});

export async function requeueStale(graceSeconds = 0): Promise<number> {
  const rows = await sql<{ n: number }[]>`select public.requeue_stale_push(${graceSeconds}) as n`;
  return rows[0]?.n ?? 0;
}

export async function claim(batch = 50, leaseSeconds = 120): Promise<ClaimedRow[]> {
  const rows = await sql<{ res: ClaimedRow[] | null }[]>`
    select public.claim_push_outbox(${batch}, ${leaseSeconds}) as res`;
  return rows[0]?.res ?? [];
}

export async function report(outboxId: string, claimId: string, results: DeviceResult[]): Promise<boolean> {
  const rows = await sql<{ ok: boolean }[]>`
    select public.report_push_results(${outboxId}::uuid, ${claimId}::uuid, ${JSON.stringify(results)}::jsonb) as ok`;
  return rows[0]?.ok ?? false;
}
