import { ClaimedRow } from "./types.ts";

// Privacy-safe FCM v1 message construction. title/body come straight from the
// canonical notification (already privacy-safe: chat is "New message" + store
// name, never counterpart identity). Only ids + route travel in `data`; no chat
// text, order totals, or personal data. Android-only for v1 (iOS/APNs deferred).

const TITLE_MAX = 120;
const BODY_MAX = 240;

function truncate(value: string | null, max: number): string {
  const v = (value ?? "").trim();
  return v.length <= max ? v : v.slice(0, max - 1) + "…";
}

export function buildMessage(row: ClaimedRow, token: string): Record<string, unknown> {
  const data: Record<string, string> = { notification_id: row.data.notification_id };
  if (row.data.route) data.route = row.data.route;
  if (row.data.event) data.event = row.data.event;

  return {
    message: {
      token,
      notification: {
        title: truncate(row.title, TITLE_MAX),
        body: truncate(row.body, BODY_MAX),
      },
      data,
      android: {
        priority: "HIGH",
        notification: { channel_id: "aurivo_default" },
      },
    },
  };
}
