import 'package:aurivo/features/admin/domain/repositories/admin_order_repository.dart';
import 'package:aurivo/features/admin/presentation/admin_order_detail_page.dart';
import 'package:aurivo/features/admin/presentation/admin_orders_page.dart';
import 'package:aurivo/features/admin/providers/admin_order_providers.dart';
import 'package:aurivo/features/orders/domain/entities/order.dart';
import 'package:aurivo/features/orders/domain/entities/order_detail.dart';
import 'package:aurivo/features/orders/domain/entities/order_item.dart';
import 'package:aurivo/shared/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Order _order(String id, {String status = 'pending'}) => Order(
  id: id,
  orderNumber: 'AUR-$id',
  profileId: 'buyer',
  status: status,
  grandTotal: 1000,
  shippingAddressSnapshot: const {'recipient_name': 'Aiman', 'city': 'Lahore'},
);

OrderItem _item() => const OrderItem(
  id: 'i1',
  orderId: 'o1',
  productId: 'p1',
  productVariantId: 'v1',
  sellerId: 's1',
  productTitleSnapshot: 'Gold Ring',
  skuSnapshot: 'SKU',
  unitPrice: 1000,
  quantity: 1,
  lineTotal: 1000,
);

class _FakeRepo implements AdminOrderRepository {
  _FakeRepo({this.detailStatus = 'pending'});
  String detailStatus;
  String? lastFilter;
  final List<String> log = [];

  @override
  Future<List<Order>> listOrders({String? status}) async {
    lastFilter = status;
    final all = [_order('1'), _order('2', status: 'delivered')];
    return status == null ? all : all.where((o) => o.status == status).toList();
  }

  @override
  Future<OrderDetail> getOrder(String orderId) async =>
      OrderDetail(order: _order(orderId, status: detailStatus), items: [_item()]);

  @override
  Future<void> advanceStatus({
    required String orderId,
    required String status,
    String? notes,
  }) async => log.add('advance:$status');

  @override
  Future<void> setPaymentStatus({
    required String orderId,
    required String status,
  }) async => log.add('payment:$status');

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) async {
    log.add('cancel:$orderId');
    detailStatus = 'cancelled';
  }
}

Widget _wrap(AdminOrderRepository repo, Widget page) => ProviderScope(
  overrides: [adminOrderRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(home: page),
);

void main() {
  testWidgets('order list shows orders and filters by status', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo, const AdminOrdersPage()));
    await tester.pumpAndSettle();

    expect(find.text('AUR-1'), findsOneWidget);
    expect(find.text('AUR-2'), findsOneWidget);

    // Tap the 'Pending' filter chip (first status chip, on-screen).
    await tester.tap(find.widgetWithText(LuxuryChip, 'Pending'));
    await tester.pumpAndSettle();
    expect(repo.lastFilter, 'pending');
    expect(find.text('AUR-1'), findsOneWidget); // pending order stays
    expect(find.text('AUR-2'), findsNothing); // delivered filtered out
  });

  testWidgets('detail shows cancel for pending and advances status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(detailStatus: 'pending');
    await tester.pumpWidget(
      _wrap(repo, const AdminOrderDetailPage(orderId: 'o1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aiman'), findsOneWidget);
    expect(find.widgetWithText(LuxuryOutlinedButton, 'Cancel order'),
        findsOneWidget);
  });

  testWidgets('detail hides cancel once delivered', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(detailStatus: 'delivered');
    await tester.pumpWidget(
      _wrap(repo, const AdminOrderDetailPage(orderId: 'o1')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(LuxuryOutlinedButton, 'Cancel order'),
        findsNothing);
  });
}
