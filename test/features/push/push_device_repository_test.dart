import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/push/data/push_device_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubDb extends SupabaseDatabaseService {
  _StubDb() : super(supabaseService: const SupabaseService());

  final calls = <String>[];
  final params = <Map<String, dynamic>>[];

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    calls.add(functionName);
    this.params.add(params);
    return null;
  }
}

void main() {
  late _StubDb db;
  late PushDeviceRepository repo;

  setUp(() {
    db = _StubDb();
    repo = PushDeviceRepository(database: db);
  });

  test('register calls register_push_device with no profile_id', () async {
    await repo.register(
      installationId: 'i1',
      platform: 'android',
      token: 't1',
      permissionStatus: 'granted',
      appVersion: '1.0.0',
    );
    expect(db.calls.single, 'register_push_device');
    final p = db.params.single;
    expect(p['p_installation_id'], 'i1');
    expect(p['p_platform'], 'android');
    expect(p['p_token'], 't1');
    expect(p['p_permission_status'], 'granted');
    expect(p['p_app_version'], '1.0.0');
    expect(p.containsKey('p_profile_id'), isFalse);
  });

  test('register omits app_version when null; keeps permission separate',
      () async {
    await repo.register(
      installationId: 'i1',
      platform: 'android',
      token: 't1',
      permissionStatus: 'denied',
    );
    final p = db.params.single;
    expect(p.containsKey('p_app_version'), isFalse);
    expect(p['p_permission_status'], 'denied');
  });

  test('unregister / setPermission / setEnabled call the correct RPCs',
      () async {
    await repo.unregister('i1');
    await repo.setPermission(installationId: 'i1', status: 'granted');
    await repo.setEnabled(installationId: 'i1', enabled: false);
    expect(db.calls, [
      'unregister_push_device',
      'set_push_permission',
      'set_push_enabled',
    ]);
    expect(db.params[0]['p_installation_id'], 'i1');
    expect(db.params[1]['p_status'], 'granted');
    expect(db.params[2]['p_enabled'], false);
    // None of these ever pass a profile_id.
    for (final p in db.params) {
      expect(p.containsKey('p_profile_id'), isFalse);
    }
  });
}
