import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/notifications/data/repositories/supabase_notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> notifRow({
  String id = 'n1',
  String? readAt,
  String? deletedAt,
}) => {
  'id': id,
  'profile_id': 'me',
  'type': 'order_update',
  'title': 'Order shipped',
  'body': 'Your order is on the way',
  'data': {'route': '/orders/1'},
  'read_at': readAt,
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  List<Map<String, dynamic>> rows = const [];
  Object? listError;
  final List<Map<String, dynamic>> updated = [];

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
    if (listError != null) throw listError!;
    return rows;
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_match': '$matchColumn=$matchValue', ...values});
    return {'id': matchValue, ...values};
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseNotificationRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseNotificationRepository(database: db);
  });

  test('getNotifications maps rows and drops soft-deleted', () async {
    db.rows = [
      notifRow(id: 'a'),
      notifRow(id: 'b', deletedAt: '2026-08-15T00:00:00Z'),
    ];
    final list = await repo.getNotifications();
    expect(list.map((n) => n.id), ['a']);
    expect(list.single.route, '/orders/1');
    expect(list.single.isRead, isFalse);
  });

  test('unreadCount counts only unread', () async {
    db.rows = [
      notifRow(id: 'a'),
      notifRow(id: 'b', readAt: '2026-08-15T00:00:00Z'),
      notifRow(id: 'c'),
    ];
    expect(await repo.unreadCount(), 2);
  });

  test('markRead sets read_at on the row', () async {
    await repo.markRead('n1');
    final row = db.updated.single;
    expect(row['_match'], 'id=n1');
    expect(row['read_at'], isNotNull);
  });

  test('markAllRead updates every unread row', () async {
    db.rows = [
      notifRow(id: 'a'),
      notifRow(id: 'b', readAt: '2026-08-15T00:00:00Z'),
      notifRow(id: 'c'),
    ];
    await repo.markAllRead();
    expect(db.updated.map((u) => u['_match']), ['id=a', 'id=c']);
  });

  test('delete soft-deletes', () async {
    await repo.delete('n1');
    final row = db.updated.single;
    expect(row['deleted_at'], isNotNull);
  });

  test('maps a failure to the shared Failure type', () async {
    db.listError = const ex.DatabaseException('boom', code: '42501');
    await expectLater(repo.getNotifications(), throwsA(isA<Failure>()));
  });
}
