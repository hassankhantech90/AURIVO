// Shared types for the push-dispatch worker. Mirrors the JSON shapes returned by
// and sent to the migration-24 worker RPCs (claim_push_outbox / report_push_results).

export type Platform = "android" | "ios";
export type Outcome = "delivered" | "invalid" | "transient";

export interface ClaimedDevice {
  device_id: string;
  token: string;
  platform: Platform;
}

export interface ClaimedRow {
  outbox_id: string;
  claim_id: string;
  notification_id: string;
  title: string | null;
  body: string | null;
  data: { notification_id: string; route: string | null; event: string | null };
  devices: ClaimedDevice[];
}

export interface DeviceResult {
  device_id: string;
  // Exactly one outcome per claimed device. The DB RPC rejects the whole report
  // unless the reported device set == claimed_device_ids.
  outcome: Outcome;
}
