/// Supported runtime environments for Pareezay.Hub infrastructure configuration.
enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromName(String value) {
    return switch (value.toLowerCase()) {
      'production' || 'prod' => AppEnvironment.production,
      'staging' || 'stage' => AppEnvironment.staging,
      _ => AppEnvironment.development,
    };
  }
}

/// Compile-time Supabase configuration loaded through dart-define values.
class SupabaseConfig {
  const SupabaseConfig._();

  static const environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hbstqyelfhihiibkfuzi.supabase.co',
  );

  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static AppEnvironment get environment =>
      AppEnvironment.fromName(environmentName);

  static bool get hasAnonKey => anonKey.trim().isNotEmpty;

  static bool get isConfigured => url.trim().isNotEmpty && hasAnonKey;

  static bool get shouldRequireCredentials =>
      environment == AppEnvironment.production;
}
