import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/support/data/repositories/supabase_support_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> ticketRow({String id = 't1', String? deletedAt}) => {
  'id': id,
  'profile_id': 'me',
  'subject': 'Where is my order',
  'description': 'It has been a while and no update at all.',
  'category': 'order',
  'priority': 'normal',
  'status': 'open',
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  List<Map<String, dynamic>> rows = const [];
  Object? insertError;
  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<Map<String, Object?>> listFilters = [];
  String profileId = 'me';

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
    listFilters.add(filters);
    return rows;
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add(values);
    return {...ticketRow(), ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_match': '$matchColumn=$matchValue', ...values});
    return {...ticketRow(id: matchValue as String), ...values};
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async => profileId;
}

void main() {
  late _StubDatabase db;
  late SupabaseSupportRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseSupportRepository(database: db);
  });

  test('create resolves the owner server-side and trims fields', () async {
    await repo.create(
      subject: '  Help  ',
      description: '  Something is wrong with my order.  ',
      category: 'order',
    );
    final row = db.inserted.single;
    expect(row['profile_id'], 'me');
    expect(row['subject'], 'Help');
    expect(row['category'], 'order');
    expect(row['status'], isNot('closed')); // status defaults server-side
  });

  test('list filters by status and drops soft-deleted', () async {
    db.rows = [
      ticketRow(id: 'a'),
      ticketRow(id: 'b', deletedAt: '2026-08-15T00:00:00Z'),
    ];
    final tickets = await repo.list(status: 'open');
    expect(tickets.map((t) => t.id), ['a']);
    expect(db.listFilters.single['status'], 'open');
  });

  test('assignToMe sets assigned_to to the current profile', () async {
    await repo.assignToMe('t1');
    expect(db.updated.single['assigned_to'], 'me');
  });

  test('setStatus sets closed_at only when closing', () async {
    await repo.setStatus(id: 't1', status: 'resolved');
    expect(db.updated.last['closed_at'], isNull);
    await repo.setStatus(id: 't1', status: 'closed');
    expect(db.updated.last['closed_at'], isNotNull);
  });

  test('maps a check violation (23514) to a Failure', () async {
    db.insertError = const ex.DatabaseException('bad', code: '23514');
    await expectLater(
      repo.create(subject: 'x', description: 'short'),
      throwsA(predicate((e) => e is Failure && e.code == '23514')),
    );
  });
}
