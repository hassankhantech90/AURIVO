import { ClaimedEmail } from "./queue.ts";

// Renders a notification as a branded Pareezay.Hub email (HTML + plain text).
// Everything user-derived is HTML-escaped; the deep link only ever points at
// APP_URL + an app-internal route ("/..."), never an arbitrary URL.

const GOLD = "#B8893B";
const CHARCOAL = "#1E1E1E";

export function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function safeLink(appUrl: string, route: string | null): string | null {
  if (!appUrl || !route || !route.startsWith("/") || route.startsWith("//")) return null;
  return appUrl.replace(/\/+$/, "") + route;
}

export function render(row: ClaimedEmail, appUrl: string): {
  subject: string;
  html: string;
  text: string;
} {
  const subject = `${row.subject} · Pareezay.Hub`.slice(0, 200);
  const greeting = row.name ? `Hi ${row.name.split(" ")[0]},` : "Hi,";
  const link = safeLink(appUrl, row.route);

  const text = [
    greeting,
    "",
    row.subject,
    row.body,
    ...(link ? ["", `Open in Pareezay.Hub: ${link}`] : []),
    "",
    "— Pareezay.Hub",
    "You received this because you have an account on Pareezay.Hub.",
  ].join("\n");

  const button = link
    ? `<p style="margin:28px 0 0"><a href="${escapeHtml(link)}" style="background:${GOLD};color:#fff;text-decoration:none;padding:12px 22px;border-radius:6px;font-weight:600;display:inline-block">Open in Pareezay.Hub</a></p>`
    : "";

  const html = `<!doctype html>
<html><body style="margin:0;background:#f6f3ee;font-family:Arial,Helvetica,sans-serif;color:${CHARCOAL}">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#fff;border-radius:10px">
<tr><td style="padding:24px 32px;border-bottom:2px solid ${GOLD};font-size:22px;letter-spacing:1px;font-weight:700">PAREEZAY<span style="color:${GOLD}">.HUB</span></td></tr>
<tr><td style="padding:28px 32px;font-size:15px;line-height:1.6">
<p style="margin:0 0 16px">${escapeHtml(greeting)}</p>
<h1 style="margin:0 0 12px;font-size:19px">${escapeHtml(row.subject)}</h1>
<p style="margin:0">${escapeHtml(row.body)}</p>
${button}
</td></tr>
<tr><td style="padding:18px 32px;font-size:12px;color:#888;border-top:1px solid #eee">You received this because you have an account on Pareezay.Hub.</td></tr>
</table></td></tr></table>
</body></html>`;

  return { subject, html, text };
}
