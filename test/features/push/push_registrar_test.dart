import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/push/data/push_device_repository.dart';
import 'package:aurivo/features/push/services/installation_id_service.dart';
import 'package:aurivo/features/push/services/push_registrar.dart';
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

class _FakeInstall implements InstallationIdService {
  int calls = 0;
  @override
  Future<String> getOrCreate() async {
    calls++;
    return 'inst-xyz';
  }
}

void main() {
  late _StubDb db;
  late _FakeInstall install;
  late PushRegistrar registrar;

  setUp(() {
    db = _StubDb();
    install = _FakeInstall();
    registrar = PushRegistrar(
      repository: PushDeviceRepository(database: db),
      installationIds: install,
    );
  });

  test('register resolves the installation id and forwards fields', () async {
    await registrar.register(token: 'tok', permissionStatus: 'granted');
    expect(install.calls, 1);
    expect(db.calls.single, 'register_push_device');
    final p = db.params.single;
    expect(p['p_installation_id'], 'inst-xyz');
    expect(p['p_platform'], 'android');
    expect(p['p_token'], 'tok');
    expect(p['p_permission_status'], 'granted');
    expect(p.containsKey('p_profile_id'), isFalse);
  });

  test('unregister targets only this installation', () async {
    await registrar.unregister();
    expect(db.calls.single, 'unregister_push_device');
    expect(db.params.single['p_installation_id'], 'inst-xyz');
  });

  test('updatePermission uses set_push_permission for this installation',
      () async {
    await registrar.updatePermission('denied');
    expect(db.calls.single, 'set_push_permission');
    expect(db.params.single['p_installation_id'], 'inst-xyz');
    expect(db.params.single['p_status'], 'denied');
  });
}
