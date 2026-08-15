import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/domain/repositories/admin_order_repository.dart';
import 'package:aurivo/features/admin/providers/admin_order_providers.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart'
    show AdminStatus;
import 'package:aurivo/features/orders/domain/entities/order.dart';
import 'package:aurivo/features/orders/domain/entities/order_detail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Order _order(String id, {String status = 'pending'}) => Order(
  id: id,
  orderNumber: 'AUR-$id',
  profileId: 'buyer',
  status: status,
);

class _FakeRepo implements AdminOrderRepository {
  String? lastStatusFilter;
  final List<String> log = [];
  String detailStatus = 'pending';

  @override
  Future<List<Order>> listOrders({String? status}) async {
    lastStatusFilter = status;
    return status == null
        ? [_order('1'), _order('2', status: 'confirmed')]
        : [_order('1', status: status)];
  }

  @override
  Future<OrderDetail> getOrder(String orderId) async =>
      OrderDetail(order: _order(orderId, status: detailStatus));

  @override
  Future<void> advanceStatus({
    required String orderId,
    required String status,
    String? notes,
  }) async {
    log.add('advance:$orderId:$status');
    detailStatus = status;
  }

  @override
  Future<void> setPaymentStatus({
    required String orderId,
    required String status,
  }) async => log.add('payment:$orderId:$status');

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) async {
    log.add('cancel:$orderId');
    detailStatus = 'cancelled';
  }
}

ProviderContainer _container(AdminOrderRepository repo) {
  final container = ProviderContainer(
    overrides: [adminOrderRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('orders list loads and applies a status filter', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final n = container.read(adminOrdersProvider.notifier);
    await n.load();
    expect(container.read(adminOrdersProvider).status, AdminStatus.success);
    expect(container.read(adminOrdersProvider).data, hasLength(2));

    await n.load(status: 'confirmed', setFilter: true);
    expect(repo.lastStatusFilter, 'confirmed');
    expect(n.statusFilter, 'confirmed');
    expect(container.read(adminOrdersProvider).data, hasLength(1));
  });

  test('detail advanceStatus reloads with the new status', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final n = container.read(adminOrderDetailProvider('o1').notifier);
    await n.load();
    expect(container.read(adminOrderDetailProvider('o1')).value!.order.status,
        'pending');

    final err = await n.advanceStatus('processing');
    expect(err, isNull);
    expect(repo.log, contains('advance:o1:processing'));
    expect(container.read(adminOrderDetailProvider('o1')).value!.order.status,
        'processing');
  });

  test('detail cancel calls the repo and reloads cancelled', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final n = container.read(adminOrderDetailProvider('o1').notifier);
    await n.load();
    final err = await n.cancel(reason: 'x');
    expect(err, isNull);
    expect(repo.log, contains('cancel:o1'));
    expect(container.read(adminOrderDetailProvider('o1')).value!.order.status,
        'cancelled');
  });

  test('detail action surfaces error message on failure', () async {
    final container = _container(_ThrowingRepo());
    final n = container.read(adminOrderDetailProvider('o1').notifier);
    await n.load();
    final err = await n.setPaymentStatus('paid');
    expect(err, contains('nope'));
  });
}

class _ThrowingRepo extends _FakeRepo {
  @override
  Future<void> setPaymentStatus({
    required String orderId,
    required String status,
  }) async => throw const Failure(message: 'nope');
}
