import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/orders/domain/entities/order.dart';
import 'package:aurivo/features/orders/domain/entities/order_detail.dart';
import 'package:aurivo/features/orders/domain/repositories/order_repository.dart';
import 'package:aurivo/features/orders/providers/order_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Order _order({String id = 'o1', String status = 'pending'}) => Order.fromMap({
  'id': id,
  'order_number': 'AUR1',
  'profile_id': 'p1',
  'status': status,
});

class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({this.listError, this.cancelError});

  final Object? listError;
  final Object? cancelError;
  String status = 'pending';

  int getOrderCalls = 0;
  int cancelCalls = 0;

  @override
  Future<List<Order>> getOrders({int limit = 50, int offset = 0}) async {
    if (listError != null) throw listError!;
    return [_order()];
  }

  @override
  Future<OrderDetail> getOrder(String orderId) async {
    getOrderCalls++;
    return OrderDetail(order: _order(id: orderId, status: status));
  }

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) async {
    cancelCalls++;
    if (cancelError != null) throw cancelError!;
    status = 'cancelled';
  }
}

ProviderContainer _container(OrderRepository repo) {
  final container = ProviderContainer(
    overrides: [orderRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ordersProvider', () {
    test('load success exposes the orders', () async {
      final container = _container(_FakeOrderRepository());

      await container.read(ordersProvider.notifier).load();

      final state = container.read(ordersProvider);
      expect(state.status, OrderViewStatus.success);
      expect(state.data!.length, 1);
    });

    test('load failure sets the message', () async {
      final container = _container(
        _FakeOrderRepository(listError: const Failure(message: 'offline')),
      );

      await container.read(ordersProvider.notifier).load();

      final state = container.read(ordersProvider);
      expect(state.status, OrderViewStatus.failure);
      expect(state.message, 'offline');
    });
  });

  group('orderDetailProvider', () {
    test('load success exposes the detail', () async {
      final container = _container(_FakeOrderRepository());

      await container.read(orderDetailProvider('o1').notifier).load();

      final state = container.read(orderDetailProvider('o1'));
      expect(state.status, OrderViewStatus.success);
      expect(state.data!.order.id, 'o1');
    });

    test('cancel success returns true and reloads the order', () async {
      final repo = _FakeOrderRepository();
      final container = _container(repo);
      final notifier = container.read(orderDetailProvider('o1').notifier);
      await notifier.load();

      final ok = await notifier.cancel(reason: 'changed mind');

      expect(ok, isTrue);
      expect(repo.cancelCalls, 1);
      // one load + one reload after cancel
      expect(repo.getOrderCalls, 2);
      expect(
        container.read(orderDetailProvider('o1')).data!.order.status,
        'cancelled',
      );
    });

    test('cancel failure returns false and surfaces the message', () async {
      final repo = _FakeOrderRepository(
        cancelError: const Failure(
          message: 'Order can no longer be cancelled.',
        ),
      );
      final container = _container(repo);
      final notifier = container.read(orderDetailProvider('o1').notifier);
      await notifier.load();

      final ok = await notifier.cancel();

      expect(ok, isFalse);
      final state = container.read(orderDetailProvider('o1'));
      expect(state.status, OrderViewStatus.failure);
      expect(state.message, 'Order can no longer be cancelled.');
    });
  });
}
