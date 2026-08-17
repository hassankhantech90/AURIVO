import '../../../../core/supabase/supabase_database_service.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../notification_failure_mapper.dart';

/// Supabase-backed [NotificationRepository]. Relies entirely on the owner-scoped
/// `notifications_owner_all` RLS (`profile_id = current_profile_id()`); it never
/// bypasses security and takes no profile id from the UI. Soft-deleted rows are
/// filtered client-side (the shared query helper supports equality filters, not
/// `IS NULL`).
class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _table = 'notifications';

  String get _now => DateTime.now().toUtc().toIso8601String();

  @override
  Future<List<AppNotification>> getNotifications({int limit = 100}) async {
    try {
      final rows = await _database.list(
        table: _table,
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
      );
      return rows
          .where((r) => r['deleted_at'] == null)
          .map(AppNotification.fromMap)
          .toList();
    } catch (error) {
      throw NotificationFailureMapper.map(error);
    }
  }

  @override
  Future<int> unreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _database.update(
        table: _table,
        values: {'read_at': _now},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw NotificationFailureMapper.map(error);
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      final unread = (await getNotifications()).where((n) => !n.isRead);
      for (final n in unread) {
        await _database.update(
          table: _table,
          values: {'read_at': _now},
          matchColumn: 'id',
          matchValue: n.id,
        );
      }
    } catch (error) {
      throw NotificationFailureMapper.map(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _database.update(
        table: _table,
        values: {'deleted_at': _now},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw NotificationFailureMapper.map(error);
    }
  }
}
