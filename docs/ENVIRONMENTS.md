# Environments

| | Development | Production |
|---|---|---|
| Supabase project | `hbstqyelfhihiibkfuzi` ("AURIVO NEW") | *not created yet* |
| App config file | `env/dev.json` | `env/prod.json` |
| `APP_ENV` | `development` | `production` |
| Email codes (`EMAIL_OTP`) | `false` | `true` once SMTP is live ([EMAIL_SETUP.md](EMAIL_SETUP.md)) |
| Test data | seeded test stores and products | none |

## App config files

Builds read their config from a JSON file through `--dart-define-from-file`.

- Only the `env/*.example.json` templates are committed.
- The real `env/dev.json` and `env/prod.json` hold keys, so they are gitignored.
- To set up a machine, copy `env/dev.example.json` to `env/dev.json` and paste the anon/publishable key into it.

Run against development:

```bash
flutter run --dart-define-from-file=env/dev.json
```

In Android Studio, the `main.dart` run configuration already passes `--dart-define-from-file=env/dev.json`.

Release build:

```bash
flutter build apk --release --dart-define-from-file=env/prod.json
```

Safety nets:
- A production build (`APP_ENV=production`) refuses to start if `SUPABASE_URL` is still the development project.
- A production build also refuses to start if the anon key is missing.
- The anon/publishable key is public by design. Every permission check lives in RLS and the SECURITY DEFINER RPCs.
- **Never** put the `service_role` key, the Resend key or database passwords in an env file.

## CI

`.github/workflows/ci.yml` runs on every push to `master` and on every PR. It runs:
- `flutter analyze`
- `flutter test`
- `deno check` for each edge function

CI needs no secrets.

## Creating production later

Plan for the **Pro plan** at launch. Free projects pause after a week of inactivity and have no daily backups.

1. **Create the project.** Supabase → New project, region **Singapore** or **Mumbai** (closest to Pakistan), with a strong DB password kept in a password manager.
2. **Apply the schema.** Apply `supabase/migrations/*.sql` **in file-number order** (`01` → `51`) in the SQL editor, or with `psql -f` one file at a time.
   - The files aren't CLI-timestamped, so `supabase db push` won't order them.
   - Migrations contain schema and real defaults only, such as CMS content and the rebrand. The demo stores, products and brands in development were seeded directly, not by migrations, so production starts clean.
   - Number `10` is intentionally absent, and development has an extra live-only `30b` that has no file. Neither is needed.
3. **Extensions.** Make sure `pg_cron`, `pg_net` and `vault` are enabled. They're used by the push and email drains.
4. **Auth settings:**
   - Confirm email ON.
   - Custom SMTP and templates ([EMAIL_SETUP.md](EMAIL_SETUP.md)).
   - Site URL set to the real domain.
   - Redirect URLs.
   - MFA (TOTP) enabled, which staff accounts require.
5. **Storage.** The buckets are created by the migrations. Verify their policies are present.
6. **Edge functions and secrets:**
   - `push-dispatch`:
     - Secrets: `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT` and `PUSH_WORKER_DB_URL`. The URL uses the `push_dispatch_worker` role; set its password with `alter role`.
     - Use a separate Firebase project for production if you want push isolation.
   - `email-dispatch`: see EMAIL_SETUP §5.
   - Store `CRON_SECRET` in the function secrets **and** in Vault (`select vault.create_secret('<value>', 'CRON_SECRET');`), then create both cron jobs.
7. **First admin.** Sign up normally, then grant the admin role in the SQL editor and enrol TOTP.
8. **App build.** Fill in `env/prod.json` with the production URL and anon key, then build with `--dart-define-from-file=env/prod.json`.
9. **Release signing.** Builds are currently debug-signed. Create an upload keystore and Play App Signing before store release. Also change the app ID from `com.example.aurivo` before the first Play upload, because it can't be changed afterwards.
