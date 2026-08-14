import 'package:aurivo/features/orders/domain/entities/shipment.dart';
import 'package:aurivo/features/seller/domain/entities/seller_order_detail.dart';
import 'package:aurivo/features/seller/domain/entities/seller_order_summary.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_order_repository.dart';
import 'package:aurivo/features/seller/presentation/seller_orders_page.dart';
import 'package:aurivo/features/seller/providers/seller_order_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerOrderSummary _summary(String id) => SellerOrderSummary(
  orderId: id,
  orderNumber: 'AUR-$id',
  status: 'confirmed',
  currency: 'PKR',
  itemCount: 2,
  sellerSubtotal: 3000,
);

class _FakeRepo implements SellerOrderRepository {
  _FakeRepo({this.orders = const []});
  final List<SellerOrderSummary> orders;

  @override
  Future<List<SellerOrderSummary>> getOrders() async => orders;

  @override
  Future<SellerOrderDetail> getOrder(String orderId) => throw UnimplementedError();
  @override
  Future<void> advanceStatus({required String orderId, required String status}) =>
      throw UnimplementedError();
  @override
  Future<Shipment> saveShipment({
    required String orderId,
    required String status,
    String? courier,
    String? trackingNumber,
    String? trackingUrl,
  }) => throw UnimplementedError();
}

Widget _wrap(SellerOrderRepository repo) => ProviderScope(
  overrides: [sellerOrderRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: SellerOrdersPage()),
);

void main() {
  testWidgets('shows empty state when there are no orders', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pumpAndSettle();
    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets('lists orders with number, status and subtotal', (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeRepo(orders: [_summary('o1'), _summary('o2')])),
    );
    await tester.pumpAndSettle();
    expect(find.text('AUR-o1'), findsOneWidget);
    expect(find.text('AUR-o2'), findsOneWidget);
    expect(find.text('Confirmed'), findsNWidgets(2));
    expect(find.text('2 items'), findsNWidgets(2));
  });
}
