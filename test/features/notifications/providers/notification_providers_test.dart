import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/notifications/domain/entities/app_notification.dart';
import 'package:aurivo/features/notifications/domain/repositories/notification_repository.dart';
import 'package:aurivo/features/notifications/providers/notification_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _n(String id, {bool read = false}) => AppNotification(
  id: id,
  profileId: 'me',
  type: 'order_update',
  title: 'T$id',
  body: 'B$id',
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
    _items = _items
        .map((n) => n.id == id ? _n(id, read: true) : n)
        .toList();
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

class _ThrowingRepo extends _FakeRepo {
  _ThrowingRepo() : super([_n('a')]);
  @override
  Future<void> markRead(String id) async =>
      throw const Failure(message: 'nope');
}

ProviderContainer _container(NotificationRepository repo) {
  final container = ProviderContainer(
    overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load exposes items and derives the unread count', () async {
    final container = _container(_FakeRepo([_n('a'), _n('b', read: true)]));
    await container.read(notificationsProvider.notifier).load();

    final state = container.read(notificationsProvider);
    expect(state.status, NotificationStatus.success);
    expect(state.items, hasLength(2));
    expect(container.read(unreadNotificationsCountProvider), 1);
  });

  test('markRead reduces the unread count', () async {
    final container = _container(_FakeRepo([_n('a'), _n('c')]));
    final notifier = container.read(notificationsProvider.notifier);
    await notifier.load();
    expect(container.read(unreadNotificationsCountProvider), 2);

    final err = await notifier.markRead('a');
    expect(err, isNull);
    expect(container.read(unreadNotificationsCountProvider), 1);
  });

  test('markAllRead clears the unread count', () async {
    final container = _container(_FakeRepo([_n('a'), _n('c')]));
    final notifier = container.read(notificationsProvider.notifier);
    await notifier.load();
    await notifier.markAllRead();
    expect(container.read(unreadNotificationsCountProvider), 0);
  });

  test('remove deletes from the list', () async {
    final container = _container(_FakeRepo([_n('a'), _n('c')]));
    final notifier = container.read(notificationsProvider.notifier);
    await notifier.load();
    await notifier.remove('a');
    expect(container.read(notificationsProvider).items.map((n) => n.id), ['c']);
  });

  test('surfaces error message on failure', () async {
    final container = _container(_ThrowingRepo());
    final notifier = container.read(notificationsProvider.notifier);
    await notifier.load();
    final err = await notifier.markRead('a');
    expect(err, contains('nope'));
  });
}
