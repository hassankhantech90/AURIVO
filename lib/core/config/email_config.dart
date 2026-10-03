/// Auth-email behaviour, chosen at build time.
///
/// `EMAIL_OTP=true` (via `--dart-define` / `env/*.json`) once custom SMTP is
/// live and the Supabase "Confirm signup" + "Reset password" templates send a
/// 6-digit `{{ .Token }}` code (see docs/EMAIL_SETUP.md). Until then the
/// built-in Supabase mailer only sends confirmation LINKS, so sign-up uses the
/// "check your email" screen and password reset is handled by support.
class EmailConfig {
  const EmailConfig._();

  static const bool otpCodes = bool.fromEnvironment('EMAIL_OTP');
}
