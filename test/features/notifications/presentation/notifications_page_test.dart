import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/notifications/domain/entities/app_notification.dart';
import 'package:aurivo/features/notifications/domain/repositories/notification_repository.dart';
import 'package:aurivo/features/notifications/presentation/notifications_page.dart';
import 'package:aurivo/features/notifications/providers/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthedSession extends SessionNotifier {
  _AuthedSession()
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      ) {
    state = const SessionState(status: SessionStatus.authenticated);
  }
}

AppNotification _n(String id, {bool read = false}) => AppNotification(
  id: id,
  profileId: 'me',
  type: 'order_update',
  title: 'Title $id',
  body: 'Body $id',
  readAt: read ? DateTime(2026) : null,
);

class _FakeRepo implements NotificationRepository {
  _FakeRepo(this._items);
  List<AppNotification> _items;
  final List<String> log = [];

  @override
  Future<List<AppNotification>> getNotifications({int limit = 100}) async =>
      _items;
  @override
  Future<int> unreadCount() async => _items.where((n) => !n.isRead).length;
  @override
  Future<void> markRead(String id) async {
    log.add('read:$id');
    _items = _items.map((n) => n.id == id ? _n(id, read: true) : n).toList();
  }

  @override
  Future<void> markAllRead() async {
    log.add('readAll');
    _items = _items.map((n) => _n(n.id, read: true)).toList();
  }

  @override
  Future<void> delete(String id) async {
    log.add('delete:$id');
    _items = _items.where((n) => n.id != id).toList();
  }
}

Widget _wrap(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(home: NotificationsPage()),
);

void main() {
  testWidgets('guests are prompted to sign in', (tester) async {
    await tester.pumpWidget(
      _wrap([notificationRepositoryProvider.overrideWithValue(_FakeRepo([]))]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in for notifications'), findsOneWidget);
  });

  testWidgets('lists notifications and marks one read on tap', (tester) async {
    final repo = _FakeRepo([_n('1'), _n('2', read: true)]);
    await tester.pumpWidget(
      _wrap([
        notificationRepositoryProvider.overrideWithValue(repo),
        sessionProvider.overrideWith((ref) => _AuthedSession()),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget); // 1 unread

    await tester.tap(find.text('Title 1'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('read:1'));
    // No unread left -> the action disappears.
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('mark all read clears unread', (tester) async {
    final repo = _FakeRepo([_n('1'), _n('2')]);
    await tester.pumpWidget(
      _wrap([
        notificationRepositoryProvider.overrideWithValue(repo),
        sessionProvider.overrideWith((ref) => _AuthedSession()),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('readAll'));
    expect(find.text('Mark all read'), findsNothing);
  });
}
