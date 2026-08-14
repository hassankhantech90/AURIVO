import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/orders/domain/entities/shipment.dart';
import 'package:aurivo/features/seller/domain/entities/seller_order_detail.dart';
import 'package:aurivo/features/seller/domain/entities/seller_order_summary.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_order_repository.dart';
import 'package:aurivo/features/seller/providers/seller_order_providers.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart'
    show SellerViewStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerOrderSummary _summary(String id) => SellerOrderSummary(
  orderId: id,
  orderNumber: 'AUR-$id',
  status: 'confirmed',
  currency: 'PKR',
  itemCount: 1,
  sellerSubtotal: 1000,
);

SellerOrderDetail _detail(String id, {String status = 'confirmed'}) =>
    SellerOrderDetail.fromParts(
      header: {
        'order_id': id,
        'order_number': 'AUR-$id',
        'status': status,
        'currency': 'PKR',
        'shipping_address_snapshot': {'city': 'Lahore'},
      },
      items: const [],
    );

class _FakeRepo implements SellerOrderRepository {
  _FakeRepo({this.getError});
  final Object? getError;

  int advanceCalls = 0;
  int shipmentCalls = 0;
  String detailStatus = 'confirmed';

  @override
  Future<List<SellerOrderSummary>> getOrders() async {
    if (getError != null) throw getError!;
    return [_summary('o1'), _summary('o2')];
  }

  @override
  Future<SellerOrderDetail> getOrder(String orderId) async {
    if (getError != null) throw getError!;
    return _detail(orderId, status: detailStatus);
  }

  @override
  Future<void> advanceStatus({
    required String orderId,
    required String status,
  }) async {
    advanceCalls++;
    detailStatus = status; // reflected on the next getOrder reload
  }

  @override
  Future<Shipment> saveShipment({
    required String orderId,
    required String status,
    String? courier,
    String? trackingNumber,
    String? trackingUrl,
  }) async {
    shipmentCalls++;
    return Shipment(id: 's1', orderId: orderId, status: status);
  }
}

ProviderContainer _container(SellerOrderRepository repo) {
  final container = ProviderContainer(
    overrides: [sellerOrderRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sellerOrdersProvider.load exposes the orders', () async {
    final container = _container(_FakeRepo());
    await container.read(sellerOrdersProvider.notifier).load();
    final state = container.read(sellerOrdersProvider);
    expect(state.status, SellerViewStatus.success);
    expect(state.data!.map((o) => o.orderId), ['o1', 'o2']);
  });

  test('sellerOrdersProvider maps failure', () async {
    final container = _container(
      _FakeRepo(getError: const Failure(message: 'nope')),
    );
    await container.read(sellerOrdersProvider.notifier).load();
    expect(container.read(sellerOrdersProvider).status, SellerViewStatus.failure);
  });

  test('detail load then advanceStatus reloads with new status', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(sellerOrderDetailProvider('o1').notifier);
    await notifier.load();
    expect(container.read(sellerOrderDetailProvider('o1')).data!.status,
        'confirmed');

    final err = await notifier.advanceStatus('shipped');
    expect(err, isNull);
    expect(repo.advanceCalls, 1);
    expect(container.read(sellerOrderDetailProvider('o1')).data!.status,
        'shipped');
  });

  test('saveShipment succeeds and reloads', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(sellerOrderDetailProvider('o1').notifier);
    await notifier.load();
    final err = await notifier.saveShipment(status: 'shipped', courier: 'TCS');
    expect(err, isNull);
    expect(repo.shipmentCalls, 1);
  });
}
