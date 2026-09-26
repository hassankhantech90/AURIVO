import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/admin/data/repositories/supabase_admin_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> profileRow({String id = 'p1', String? deletedAt}) => {
  'id': id,
  'user_id': 'u-$id',
  'full_name': 'User $id',
  'status': 'active',
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Map<String, List<Map<String, dynamic>>> tables = {};
  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<Map<String, Object?>> deleted = [];
  Object? insertError;

  @override
  Future<List<Map<String, dynamic>>> list({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
    Map<String, List<Object>> whereIn = const {},
    String? ilikeColumn,
    String? ilikeQuery,
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    var rows = tables[table] ?? const [];
    for (final f in filters.entries) {
      rows = rows.where((r) => r[f.key] == f.value).toList();
    }
    return rows;
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add({'_table': table, ...values});
    return {'id': 'new', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_table': table, '_match': '$matchColumn=$matchValue', ...values});
    return {'id': matchValue, ...values};
  }

  @override
  Future<void> delete({
    required String table,
    required String matchColumn,
    required Object matchValue,
  }) async {
    deleted.add({'_table': table, matchColumn: matchValue});
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseAdminUserRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseAdminUserRepository(database: db);
  });

  test('listUsers joins each profile to its roles', () async {
    db.tables = {
      'profiles': [profileRow(id: 'p1'), profileRow(id: 'p2', deletedAt: '2026-08-14T00:00:00Z')],
      'roles': [
        {'id': 'r-admin', 'name': 'admin'},
        {'id': 'r-cust', 'name': 'customer'},
      ],
      'profile_roles': [
        {'id': 'a1', 'profile_id': 'p1', 'role_id': 'r-admin'},
        {'id': 'a2', 'profile_id': 'p1', 'role_id': 'r-cust'},
        {'id': 'a3', 'profile_id': 'p2', 'role_id': 'r-cust'},
      ],
    };
    final users = await repo.listUsers();
    final p1 = users.firstWhere((u) => u.profile.id == 'p1');
    final p2 = users.firstWhere((u) => u.profile.id == 'p2');
    expect(p1.roleNames..sort(), ['admin', 'customer']);
    expect(p1.hasRole('admin'), isTrue);
    expect(p2.isDeleted, isTrue);
  });

  test('setStatus updates the profile', () async {
    await repo.setStatus(profileId: 'p1', status: 'suspended');
    final row = db.updated.single;
    expect(row['_table'], 'profiles');
    expect(row['_match'], 'id=p1');
    expect(row['status'], 'suspended');
  });

  test('setDeleted sets or clears deleted_at', () async {
    await repo.setDeleted(profileId: 'p1', deleted: true);
    expect(db.updated.last['deleted_at'], isNotNull);
    await repo.setDeleted(profileId: 'p1', deleted: false);
    expect(db.updated.last['deleted_at'], isNull);
  });

  test('grantRole inserts and is idempotent on 23505', () async {
    await repo.grantRole(profileId: 'p1', roleId: 'r-seller');
    expect(db.inserted.single['profile_id'], 'p1');

    db.insertError = const ex.DatabaseException('dup', code: '23505');
    // Should not throw — already granted is treated as success.
    await repo.grantRole(profileId: 'p1', roleId: 'r-seller');
  });

  test('revokeRole finds the assignment then deletes it by id', () async {
    db.tables = {
      'profile_roles': [
        {'id': 'a1', 'profile_id': 'p1', 'role_id': 'r-seller'},
      ],
    };
    await repo.revokeRole(profileId: 'p1', roleId: 'r-seller');
    expect(db.deleted.single['id'], 'a1');
  });

  test('revokeRole is a no-op when the assignment is absent', () async {
    db.tables = {'profile_roles': const []};
    await repo.revokeRole(profileId: 'p1', roleId: 'r-seller');
    expect(db.deleted, isEmpty);
  });
}
