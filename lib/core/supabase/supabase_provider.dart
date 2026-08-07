import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_auth_service.dart';
import 'supabase_client.dart';
import 'supabase_database_service.dart';
import 'supabase_service.dart';
import 'supabase_storage_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return AppSupabaseClient.instance;
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(client: ref.watch(supabaseClientProvider));
});

final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService(
    supabaseService: ref.watch(supabaseServiceProvider),
  );
});

final supabaseDatabaseServiceProvider = Provider<SupabaseDatabaseService>((
  ref,
) {
  return SupabaseDatabaseService(
    supabaseService: ref.watch(supabaseServiceProvider),
  );
});

final supabaseStorageServiceProvider = Provider<SupabaseStorageService>((ref) {
  return SupabaseStorageService(
    supabaseService: ref.watch(supabaseServiceProvider),
  );
});
