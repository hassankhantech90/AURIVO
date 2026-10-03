# Email delivery: go-live runbook

Everything in the repo is ready, but email delivery stays **off** until you own
a domain. Two separate flows share one Resend account:

| Flow | What sends it | Turned on by |
|---|---|---|
| **Auth emails** (sign-up code, password-reset code) | Supabase Auth through custom SMTP | Steps 1–4, then the `EMAIL_OTP=true` app build |
| **Order / account emails** (order placed, status updates, returns, disputes, support) | `email_outbox` (migration 51) → `email-dispatch` edge function → Resend API | Steps 1, 2, 5 |

Until then the app behaves exactly as today:
- After sign-up, users see "check your email" with a link from Supabase's built-in mailer. That mailer only delivers to project team members.
- Password reset is handled by support.

> Do **not** turn off "Confirm email" in Supabase to work around this.

---

## 1. Resend account and domain (you do this)

1. Create an account at <https://resend.com>.
2. Go to **Domains → Add domain**. Use a subdomain such as `mail.yourdomain.pk`, so your main domain's mail reputation stays separate.
3. Add the DNS records Resend shows at your domain registrar:
   - **SPF**: TXT/MX on `send.mail…`
   - **DKIM**: TXT `resend._domainkey…`
   - **DMARC** (recommended): TXT `_dmarc.yourdomain.pk` = `v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.pk`. Tighten it to `p=quarantine` once mail is flowing cleanly.
4. Wait until the domain shows **Verified**.
5. Go to **API Keys → Create**. Use permission *Sending access*, restricted to this domain. Keep the key private. It is pasted only into the Supabase dashboard, never into the repo or chat.

## 2. Pick sender addresses

- Auth: `Pareezay.Hub <no-reply@mail.yourdomain.pk>`
- Orders: `Pareezay.Hub <orders@mail.yourdomain.pk>`. Reply-to can be your support inbox.

## 3. Supabase custom SMTP (auth emails)

Go to Dashboard → **Authentication → Emails → SMTP Settings → Enable custom SMTP**:

| Field | Value |
|---|---|
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | *your Resend API key* |
| Sender email | `no-reply@mail.yourdomain.pk` |
| Sender name | `Pareezay.Hub` |

Then:
- **Authentication → Providers → Email**:
  - **Email OTP Length = 6**: the app's code field is 6 digits.
  - Keep **Confirm email ON**.
  - Set **Email OTP Expiration** to 3600 s.
- **Authentication → Rate Limits**: raise "emails sent per hour". Custom SMTP lifts the built-in cap of 2 per hour.

## 4. Paste the templates

Go to **Authentication → Email Templates**. For each entry, paste the file from `supabase/templates/` into the body and set the subject:

| Template | File | Subject |
|---|---|---|
| Confirm signup | `confirm_signup.html` | `Your Pareezay.Hub verification code` |
| Reset password | `reset_password.html` | `Your Pareezay.Hub password reset code` |
| Magic link | `magic_link.html` | `Your Pareezay.Hub sign-in code` |
| Change email address | `email_change.html` | `Confirm your new Pareezay.Hub email` |
| Reauthentication | `reauthentication.html` | `Confirm it's you` |

The templates use `{{ .Token }}` (a 6-digit code) instead of a link. The app verifies the code on its OTP screen. That screen is already built and gated by `EMAIL_OTP`.

Also set **Authentication → URL Configuration → Site URL** to your real domain. It replaces the interim value.

Test it: sign up with a non-team address. A code email should arrive within seconds.

**Then ship an app build with codes on:** set `"EMAIL_OTP": "true"` in `env/prod.json` (see `docs/ENVIRONMENTS.md`) and rebuild. With that flag:
- After sign-up, the app goes to the code screen.
- "Forgot password" sends a reset code.

## 5. Order / account emails (email-dispatch)

### 5a. Worker DB password

In the **SQL editor**, run this with a long random password you generate. Don't paste it into chat:

```sql
alter role email_dispatch_worker with password '<generate-a-long-random-password>';
```

Build the pooled connection string: Dashboard → **Connect** → *Transaction pooler*. Replace the user with `email_dispatch_worker.<project-ref>` and use the password above.

### 5b. Function secrets

Go to **Edge Functions → Secrets**:

| Secret | Value |
|---|---|
| `RESEND_API_KEY` | Resend API key |
| `EMAIL_FROM` | `Pareezay.Hub <orders@mail.yourdomain.pk>` |
| `EMAIL_REPLY_TO` | *(optional)* your support inbox |
| `APP_URL` | *(optional)* base URL for "Open in Pareezay.Hub" buttons, e.g. `https://yourdomain.pk` |
| `EMAIL_WORKER_DB_URL` | the pooled connection string from 5a |
| `CRON_SECRET` | already set (shared with push-dispatch) |

### 5c. Deploy the function

```bash
supabase functions deploy email-dispatch --no-verify-jwt --project-ref <project-ref>
```

`--no-verify-jwt` is correct here: the function checks the `CRON_SECRET` bearer itself, exactly like push-dispatch.

### 5d. Schedule and switch on

Run in the SQL editor:

```sql
select cron.schedule('email-dispatch-drain', '* * * * *', $$
  select net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/email-dispatch',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'CRON_SECRET'),
      'Content-Type',  'application/json'),
    body    := '{}'::jsonb,
    timeout_milliseconds := 55000);
$$);

update public.email_settings set enabled = true;
-- Optional: change which notification types are emailed (default below).
-- update public.email_settings set types = '{order_update,seller_event,support,system}';
```

### 5e. Monitor

```sql
select status, terminal_reason, count(*) from email_outbox group by 1, 2;
```

- `sent`: delivered to Resend.
- `failed`: retrying with backoff (1 m, 5 m, 30 m, 2 h, 6 h).
- `dead/rejected`: bad address.
- `dead/max_attempts`: check the Resend dashboard, the key and domain verification.
- `skipped/no_address`: the user has no confirmed email.

Function logs carry only ids, HTTP status and outcome. They never include the address, the body or the key.

**Kill switch:**

```sql
update public.email_settings set enabled = false;
```

This stops new enqueues. Rows already queued still drain while the cron job runs.
