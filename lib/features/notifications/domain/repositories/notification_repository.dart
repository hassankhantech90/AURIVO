import '../entities/app_notification.dart';

/// Contract for the current user's in-app notifications.
///
/// Access is owner-scoped by RLS (`profile_id = current_profile_id()`), so no
/// profile id is ever taken from the UI. Creation is server-side only — this
/// contract is read + read-state (mark read / delete). Implementations map
/// failures to the shared `Failure` type.
abstract class NotificationRepository {
  /// The current user's notifications, newest first (excludes soft-deleted).
  Future<List<AppNotification>> getNotifications({int limit});

  /// Number of unread notifications for the current user.
  Future<int> unreadCount();

  /// Marks a single notification read.
  Future<void> markRead(String id);

  /// Marks all of the current user's unread notifications read.
  Future<void> markAllRead();

  /// Soft-deletes a notification from the user's list.
  Future<void> delete(String id);
}
