import 'dart:async';

import 'package:aurivo/features/orders/domain/entities/order_item.dart';
import 'package:aurivo/features/orders/domain/entities/shipment.dart';
import 'package:aurivo/features/seller/domain/entities/seller_order_detail.dart';
import 'package:aurivo/features/seller/domain/entities/seller_order_summary.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_order_repository.dart';
import 'package:aurivo/features/seller/presentation/seller_order_detail_page.dart';
import 'package:aurivo/features/seller/providers/seller_order_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem _item() => const OrderItem(
  id: 'i1',
  orderId: 'o1',
  productId: 'p1',
  productVariantId: 'v1',
  sellerId: 'sp1',
  productTitleSnapshot: 'Gold Ring',
  skuSnapshot: 'SKU1',
  unitPrice: 1500,
  quantity: 2,
  lineTotal: 3000,
);

class _FakeRepo implements SellerOrderRepository {
  String status = 'confirmed';
  int advanceCalls = 0;
  int shipmentCalls = 0;

  /// When set, [advanceStatus] blocks on this until completed, so a test can
  /// tap again while the first advance is still in flight.
  Completer<void>? advanceGate;

  SellerOrderDetail _detail() => SellerOrderDetail.fromParts(
    header: {
      'order_id': 'o1',
      'order_number': 'AUR-o1',
      'status': status,
      'currency': 'PKR',
      'shipping_address_snapshot': {
        'recipient_name': 'Aiman',
        'address_line_1': '1 Mall Road',
        'city': 'Lahore',
        'province': 'Punjab',
      },
    },
    items: [_item()],
  );

  @override
  Future<SellerOrderDetail> getOrder(String orderId) async => _detail();

  @override
  Future<void> advanceStatus({
    required String orderId,
    required String status,
  }) async {
    advanceCalls++;
    if (advanceGate != null) await advanceGate!.future;
    this.status = status;
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

  @override
  Future<List<SellerOrderSummary>> getOrders() async => const [];
}

Widget _wrap(SellerOrderRepository repo) => ProviderScope(
  overrides: [sellerOrderRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: SellerOrderDetailPage(orderId: 'o1')),
);

void main() {
  testWidgets('renders address, items, subtotal and no-shipment state', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Aiman'), findsOneWidget);
    expect(find.text('Gold Ring'), findsOneWidget);
    expect(find.text('Your subtotal'), findsOneWidget);
    expect(find.text('No shipment yet.'), findsOneWidget);
    expect(find.text('Mark as packed'), findsOneWidget);
  });

  testWidgets('mark as packed advances status and refreshes', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark as packed'));
    await tester.pumpAndSettle();

    expect(repo.advanceCalls, 1);
    expect(find.text('Packed'), findsOneWidget); // badge reflects new status
    expect(find.text('Mark as packed'), findsNothing); // no longer offered
  });

  testWidgets('double-tapping mark as packed advances only once', (
    tester,
  ) async {
    final repo = _FakeRepo()..advanceGate = Completer<void>();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // First tap starts the advance and disables the button.
    await tester.tap(find.text('Mark as packed'));
    await tester.pump();
    // Second tap while the first is still in flight must be ignored.
    await tester.tap(find.text('Mark as packed'), warnIfMissed: false);
    await tester.pump();

    // Let the in-flight advance complete.
    repo.advanceGate!.complete();
    await tester.pumpAndSettle();

    expect(repo.advanceCalls, 1);
  });

  testWidgets('subtotal row does not overflow at 320px / 2x text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sellerOrderRepositoryProvider.overrideWithValue(_FakeRepo()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const SellerOrderDetailPage(orderId: 'o1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your subtotal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the shipment form sheet', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add shipment details'));
    await tester.pumpAndSettle();

    expect(find.text('Add shipment'), findsOneWidget);
    expect(find.text('Save shipment'), findsOneWidget);
  });
}
