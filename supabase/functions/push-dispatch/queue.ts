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

// TEMP DIAGNOSTIC (remove after root-cause of report_rejected). Logs ONLY
// non-sensitive identifiers/types/counts — never token/DSN/secret/body.
function dlog(fields: Record<string, unknown>): void {
  console.log(JSON.stringify({ evt: "diag", ...fields }));
}

export async function requeueStale(graceSeconds = 0): Promise<number> {
  const rows = await sql<{ n: number }[]>`select public.requeue_stale_push(${graceSeconds}) as n`;
  return rows[0]?.n ?? 0;
}

export async function claim(batch = 50, leaseSeconds = 120): Promise<ClaimedRow[]> {
  const rows = await sql<{ res: ClaimedRow[] | null }[]>`
    select public.claim_push_outbox(${batch}, ${leaseSeconds}) as res`;
  const res: ClaimedRow[] = rows[0]?.res ?? [];
  // TEMP DIAGNOSTIC: exactly what claim_push_outbox returned, as mapped in-memory.
  dlog({
    where: "claim_return",
    row_count: res.length,
    rows: res.map((r) => ({
      outbox_id: r.outbox_id,
      claim_id: r.claim_id,
      claim_id_type: typeof r.claim_id,
      device_count: Array.isArray(r.devices) ? r.devices.length : null,
      device_ids: Array.isArray(r.devices) ? r.devices.map((d) => d.device_id) : null,
    })),
  });
  return res;
}

export async function report(outboxId: string, claimId: string, results: DeviceResult[]): Promise<boolean> {
  // TEMP DIAGNOSTIC: exact args (ids/types/counts only) passed into the RPC.
  dlog({
    where: "report_args",
    outbox_id: outboxId,
    outbox_id_type: typeof outboxId,
    claim_id: claimId,
    claim_id_type: typeof claimId,
    result_count: Array.isArray(results) ? results.length : null,
    reported_device_ids: Array.isArray(results) ? results.map((r) => r.device_id) : null,
    outcomes: Array.isArray(results) ? results.map((r) => r.outcome) : null,
    results_json_preview: JSON.stringify(results),
  });
  const rows = await sql<{ ok: boolean }[]>`
    select public.report_push_results(${outboxId}::uuid, ${claimId}::uuid, ${JSON.stringify(results)}::jsonb) as ok`;
  const ok = rows[0]?.ok ?? false;
  // TEMP DIAGNOSTIC: raw RPC boolean + type.
  dlog({ where: "report_return", ok, ok_type: typeof rows[0]?.ok });
  return ok;
}
