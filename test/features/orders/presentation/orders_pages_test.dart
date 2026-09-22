import 'package:aurivo/features/orders/domain/entities/order.dart';
import 'package:aurivo/features/orders/domain/entities/order_detail.dart';
import 'package:aurivo/features/orders/domain/entities/order_item.dart';
import 'package:aurivo/features/orders/domain/entities/order_status_event.dart';
import 'package:aurivo/features/orders/domain/repositories/order_repository.dart';
import 'package:aurivo/features/orders/presentation/order_detail_page.dart';
import 'package:aurivo/features/orders/presentation/orders_page.dart';
import 'package:aurivo/features/orders/providers/order_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Order _order({String id = 'o1', String status = 'pending'}) => Order.fromMap({
  'id': id,
  'order_number': 'AUR260811000001',
  'profile_id': 'p1',
  'status': status,
  'payment_status': 'pending',
  'currency': 'PKR',
  'grand_total': 1500,
  'placed_at': '2026-08-11T10:00:00Z',
});

class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({this.orders = const [], this.detail});

  final List<Order> orders;
  final OrderDetail? detail;

  @override
  Future<List<Order>> getOrders({int limit = 50, int offset = 0}) async =>
      orders;

  @override
  Future<OrderDetail> getOrder(String orderId) async =>
      detail ?? OrderDetail(order: _order(id: orderId));

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) async {}
}

Widget _wrap(Widget child, OrderRepository repo) {
  return ProviderScope(
    overrides: [orderRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('OrdersPage shows empty state when there are no orders', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const OrdersPage(), _FakeOrderRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets('OrdersPage lists orders with their number', (tester) async {
    await tester.pumpWidget(
      _wrap(const OrdersPage(), _FakeOrderRepository(orders: [_order()])),
    );
    await tester.pumpAndSettle();

    expect(find.text('AUR260811000001'), findsOneWidget);
  });

  testWidgets('OrderDetailPage renders header, items, and status timeline', (
    tester,
  ) async {
    // Tall viewport so the whole (lazy) ListView is laid out in one pump.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final detail = OrderDetail(
      order: _order(),
      items: [
        OrderItem.fromMap({
          'id': 'i1',
          'order_id': 'o1',
          'product_id': 'prod-1',
          'product_variant_id': 'var-1',
          'seller_id': 'seller-1',
          'product_title_snapshot': 'Gold Ring',
          'sku_snapshot': 'SKU-1',
          'unit_price': 750,
          'quantity': 2,
          'line_total': 1500,
          'currency': 'PKR',
        }),
      ],
      statusHistory: [
        OrderStatusEvent.fromMap({
          'id': 'e1',
          'order_id': 'o1',
          'status': 'pending',
          'notes': 'Order placed.',
          'created_at': '2026-08-11T10:00:00Z',
        }),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        const OrderDetailPage(orderId: 'o1'),
        _FakeOrderRepository(detail: detail),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AUR260811000001'), findsOneWidget);
    expect(find.text('Gold Ring'), findsOneWidget);
    expect(find.text('Order placed.'), findsOneWidget);
    // Pending orders are cancellable → the cancel CTA is offered.
    expect(find.text('Cancel order'), findsOneWidget);
  });

  testWidgets(
    'OrderDetailPage is refreshable and does not overflow at 320px / 2x scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detail = OrderDetail(
        order: Order.fromMap({
          'id': 'o1',
          'order_number': 'AUR260811000001',
          'profile_id': 'p1',
          'status': 'shipped',
          'payment_status': 'pending',
          'currency': 'PKR',
          'subtotal': 1299999,
          'grand_total': 1299999,
          'placed_at': '2026-08-11T10:00:00Z',
        }),
        items: [
          OrderItem.fromMap({
            'id': 'i1',
            'order_id': 'o1',
            'product_id': 'prod-1',
            'product_variant_id': 'var-1',
            'seller_id': 'seller-1',
            'product_title_snapshot':
                '[TEST] Handcrafted 22k Gold Diamond Solitaire '
                'Engagement Ring — Limited Heritage Edition',
            'sku_snapshot': 'SKU-1',
            'unit_price': 1299999,
            'quantity': 1,
            'line_total': 1299999,
            'currency': 'PKR',
          }),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(
              _FakeOrderRepository(detail: detail),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: const OrderDetailPage(orderId: 'o1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A1: pull-to-refresh is available on the tracking view.
      expect(find.byType(RefreshIndicator), findsOneWidget);
      // A2: no RenderFlex overflow at a large text scale.
      expect(tester.takeException(), isNull);
    },
  );
}
