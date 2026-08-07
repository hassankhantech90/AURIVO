import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Thin access layer for the configured Supabase client.
class SupabaseService {
  const SupabaseService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get client => _client ?? AppSupabaseClient.instance;
}
