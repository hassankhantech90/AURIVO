import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/push_device_repository.dart';
import '../services/installation_id_service.dart';
import '../services/push_registrar.dart';

final pushDeviceRepositoryProvider = Provider<PushDeviceRepository>((ref) {
  return const PushDeviceRepository(
    database: SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

final installationIdServiceProvider = Provider<InstallationIdService>((ref) {
  return const SecureStorageInstallationIdService();
});

final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  return PushRegistrar(
    repository: ref.watch(pushDeviceRepositoryProvider),
    installationIds: ref.watch(installationIdServiceProvider),
  );
});
