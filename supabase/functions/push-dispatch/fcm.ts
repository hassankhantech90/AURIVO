import { Outcome } from "./types.ts";

// FCM HTTP v1 client: mint an OAuth access token from the service-account private
// key (RS256, Web Crypto), cache it for the function lifetime, send one request
// per device, and classify the per-device outcome. The service account and
// tokens are never logged.

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

const SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URI_DEFAULT = "https://oauth2.googleapis.com/token";

let cachedToken: { token: string; expiresAt: number } | null = null;

function pemToPkcs8(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  // Back the view with an explicit ArrayBuffer so it is a WebCrypto-compatible
  // BufferSource (not a potentially SharedArrayBuffer-backed ArrayBufferLike).
  // The fill loop writes identical bytes, so the decoded PKCS#8 key is unchanged.
  const buf = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf;
}

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlStr(s: string): string {
  return b64url(new TextEncoder().encode(s));
}

async function mintAccessToken(sa: ServiceAccount): Promise<{ token: string; expiresAt: number }> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = { iss: sa.client_email, scope: SCOPE, aud: sa.token_uri ?? TOKEN_URI_DEFAULT, iat: now, exp: now + 3600 };
  const signingInput = `${b64urlStr(JSON.stringify(header))}.${b64urlStr(JSON.stringify(claims))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signingInput)));
  const assertion = `${signingInput}.${b64url(sig)}`;

  const res = await fetch(sa.token_uri ?? TOKEN_URI_DEFAULT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  if (!res.ok) throw new Error(`oauth_token_failed_${res.status}`);
  const json = await res.json();
  return { token: json.access_token as string, expiresAt: now + ((json.expires_in as number) ?? 3600) - 60 };
}

export async function getAccessToken(sa: ServiceAccount, forceRefresh = false): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (!forceRefresh && cachedToken && cachedToken.expiresAt > now) return cachedToken.token;
  cachedToken = await mintAccessToken(sa);
  return cachedToken.token;
}

export interface SendResult {
  httpStatus: number;
  errorCode?: string;
}

export async function sendToDevice(
  accessToken: string,
  projectId: string,
  message: Record<string, unknown>,
  validateOnly: boolean,
): Promise<SendResult> {
  const body = validateOnly ? { validate_only: true, ...message } : message;
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (res.ok) {
    await res.body?.cancel();
    return { httpStatus: res.status };
  }
  let errorCode: string | undefined;
  try {
    const j = await res.json();
    const details = j?.error?.details as Array<{ errorCode?: string }> | undefined;
    errorCode = details?.find((d) => d?.errorCode)?.errorCode ?? (j?.error?.status as string | undefined);
  } catch {
    // no structured error body
  }
  return { httpStatus: res.status, errorCode };
}

// Token-permanent failures -> soft-delete that device. INVALID_ARGUMENT here is
// treated as a bad/expired token (our payloads are well-formed).
const INVALID_CODES = new Set(["UNREGISTERED", "INVALID_ARGUMENT", "SENDER_ID_MISMATCH"]);

// Returns a device outcome, or "unauthorized" to signal an OAuth refresh + retry.
export function classify(r: SendResult): Outcome | "unauthorized" {
  if (r.httpStatus >= 200 && r.httpStatus < 300) return "delivered";
  if (r.httpStatus === 401) return "unauthorized";
  if (r.errorCode && INVALID_CODES.has(r.errorCode)) return "invalid";
  // 429 / 500 / 503 / network / THIRD_PARTY_AUTH_ERROR -> transient (DB backs off)
  return "transient";
}
