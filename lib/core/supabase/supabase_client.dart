import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/logger_service.dart';
import 'supabase_config.dart';
import 'supabase_exceptions.dart';

/// Owns Supabase SDK initialization and exposes the configured client.
class AppSupabaseClient {
  const AppSupabaseClient._();

  static Future<void> initialize({LoggerService? logger}) async {
    if (!SupabaseConfig.isConfigured) {
      final message =
          'Supabase anon key is missing. Provide SUPABASE_ANON_KEY with --dart-define.';
      if (SupabaseConfig.shouldRequireCredentials) {
        throw const SupabaseConfigurationException(
          'Supabase credentials are required in production.',
        );
      }
      logger?.warning(message);
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    logger?.info('Supabase initialized for ${SupabaseConfig.environment.name}');
  }

  static SupabaseClient get instance {
    if (!SupabaseConfig.isConfigured) {
      throw const SupabaseConfigurationException(
        'Supabase is not configured. Provide SUPABASE_ANON_KEY with --dart-define.',
      );
    }
    return Supabase.instance.client;
  }
}
