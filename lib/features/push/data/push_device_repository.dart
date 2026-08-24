import '../../../core/supabase/supabase_database_service.dart';

/// Talks only to the migration-22 SECURITY DEFINER RPCs. It never writes
/// `push_devices` directly and never passes a `profile_id` — the server resolves
/// the owner from the authenticated session (`current_profile_id()`).
class PushDeviceRepository {
  const PushDeviceRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  Future<void> register({
    required String installationId,
    required String platform,
    required String token,
    required String permissionStatus,
    String? appVersion,
  }) async {
    final params = <String, dynamic>{
      'p_installation_id': installationId,
      'p_platform': platform,
      'p_token': token,
      'p_permission_status': permissionStatus,
    };
    if (appVersion != null) params['p_app_version'] = appVersion;
    await _database.rpc(functionName: 'register_push_device', params: params);
  }

  Future<void> unregister(String installationId) {
    return _database.rpc(
      functionName: 'unregister_push_device',
      params: {'p_installation_id': installationId},
    );
  }

  Future<void> setPermission({
    required String installationId,
    required String status,
  }) {
    return _database.rpc(
      functionName: 'set_push_permission',
      params: {'p_installation_id': installationId, 'p_status': status},
    );
  }

  Future<void> setEnabled({
    required String installationId,
    required bool enabled,
  }) {
    return _database.rpc(
      functionName: 'set_push_enabled',
      params: {'p_installation_id': installationId, 'p_enabled': enabled},
    );
  }
}
