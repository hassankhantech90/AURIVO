import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/support/domain/entities/support_ticket.dart';
import 'package:aurivo/features/support/domain/repositories/support_repository.dart';
import 'package:aurivo/features/support/providers/support_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SupportTicket _t(String id, {String status = 'open'}) => SupportTicket(
  id: id,
  profileId: 'me',
  subject: 'S$id',
  description: 'A description that is long enough.',
  status: status,
);

class _FakeRepo implements SupportRepository {
  _FakeRepo(this._items);
  List<SupportTicket> _items;
  final List<String> log = [];
  String? lastStatusFilter;

  @override
  Future<List<SupportTicket>> list({String? status}) async {
    lastStatusFilter = status;
    return status == null
        ? _items
        : _items.where((t) => t.status == status).toList();
  }

  @override
  Future<SupportTicket> create({
    required String subject,
    required String description,
    String category = 'general',
    String priority = 'normal',
    String? orderId,
  }) async {
    log.add('create:$subject');
    final t = _t('new');
    _items = [t, ..._items];
    return t;
  }

  @override
  Future<void> assignToMe(String id) async => log.add('assign:$id');

  @override
  Future<void> setStatus({required String id, required String status}) async =>
      log.add('status:$id:$status');
}

class _ThrowingRepo extends _FakeRepo {
  _ThrowingRepo() : super([]);
  @override
  Future<SupportTicket> create({
    required String subject,
    required String description,
    String category = 'general',
    String priority = 'normal',
    String? orderId,
  }) async => throw const Failure(message: 'denied');
}

ProviderContainer _container(SupportRepository repo) {
  final container = ProviderContainer(
    overrides: [supportRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load exposes tickets; create prepends and reloads', () async {
    final repo = _FakeRepo([_t('1')]);
    final container = _container(repo);
    final n = container.read(ticketsProvider.notifier);
    await n.load();
    expect(container.read(ticketsProvider).status, SupportStatus.success);

    final err = await n.create(
      subject: 'Broken',
      description: 'It is really broken now.',
      category: 'technical',
    );
    expect(err, isNull);
    expect(repo.log, contains('create:Broken'));
    expect(container.read(ticketsProvider).tickets, hasLength(2));
  });

  test('load with a status filter is remembered', () async {
    final repo = _FakeRepo([_t('1', status: 'open'), _t('2', status: 'closed')]);
    final container = _container(repo);
    final n = container.read(ticketsProvider.notifier);
    await n.load(status: 'closed', setFilter: true);
    expect(repo.lastStatusFilter, 'closed');
    expect(n.statusFilter, 'closed');
    expect(container.read(ticketsProvider).tickets.single.id, '2');
  });

  test('assignToMe and setStatus call through', () async {
    final repo = _FakeRepo([_t('1')]);
    final container = _container(repo);
    final n = container.read(ticketsProvider.notifier);
    await n.load();
    expect(await n.assignToMe('1'), isNull);
    expect(await n.setStatus('1', 'resolved'), isNull);
    expect(repo.log, containsAll(['assign:1', 'status:1:resolved']));
  });

  test('surfaces error message on failure', () async {
    final container = _container(_ThrowingRepo());
    final err = await container
        .read(ticketsProvider.notifier)
        .create(subject: 'x', description: 'y', category: 'general');
    expect(err, contains('denied'));
  });
}
