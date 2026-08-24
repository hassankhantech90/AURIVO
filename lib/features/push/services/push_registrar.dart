import '../data/push_device_repository.dart';
import 'installation_id_service.dart';

/// Coordinates the device-registration lifecycle against the migration-22 RPCs,
/// resolving the installation id locally. Firebase-free so it is unit-testable.
class PushRegistrar {
  const PushRegistrar({
    required PushDeviceRepository repository,
    required InstallationIdService installationIds,
  }) : _repository = repository,
       _installationIds = installationIds;

  final PushDeviceRepository _repository;
  final InstallationIdService _installationIds;

  Future<void> register({
    required String token,
    required String permissionStatus,
    String platform = 'android',
    String? appVersion,
  }) async {
    final installationId = await _installationIds.getOrCreate();
    await _repository.register(
      installationId: installationId,
      platform: platform,
      token: token,
      permissionStatus: permissionStatus,
      appVersion: appVersion,
    );
  }

  Future<void> updatePermission(String status) async {
    final installationId = await _installationIds.getOrCreate();
    await _repository.setPermission(installationId: installationId, status: status);
  }

  Future<void> unregister() async {
    final installationId = await _installationIds.getOrCreate();
    await _repository.unregister(installationId);
  }
}
