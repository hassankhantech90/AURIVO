import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_notification_repository.dart';
import '../domain/entities/app_notification.dart';
import '../domain/repositories/notification_repository.dart';

/// Repository binding (lazy service — stays test-safe without an initialized
/// Supabase client).
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

enum NotificationStatus { initial, loading, success, failure }

class NotificationState {
  const NotificationState({
    this.status = NotificationStatus.initial,
    this.items = const [],
    this.message,
  });

  final NotificationStatus status;
  final List<AppNotification> items;
  final String? message;

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationState copyWith({
    NotificationStatus? status,
    List<AppNotification>? items,
    String? message,
    bool clearMessage = false,
  }) {
    return NotificationState(
      status: status ?? this.status,
      items: items ?? this.items,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationState>((ref) {
      return NotificationsNotifier(ref.watch(notificationRepositoryProvider));
    });

/// Unread badge count, derived from the loaded notification list.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});

class NotificationsNotifier extends StateNotifier<NotificationState> {
  NotificationsNotifier(this._repository) : super(const NotificationState());

  final NotificationRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      status: NotificationStatus.loading,
      clearMessage: true,
    );
    try {
      state = NotificationState(
        status: NotificationStatus.success,
        items: await _repository.getNotifications(),
      );
    } catch (error) {
      state = state.copyWith(
        status: NotificationStatus.failure,
        message: error.toString(),
      );
    }
  }

  /// Returns null on success or a user-facing error message.
  Future<String?> markRead(String id) => _run(() => _repository.markRead(id));

  Future<String?> markAllRead() => _run(_repository.markAllRead);

  Future<String?> remove(String id) => _run(() => _repository.delete(id));

  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
