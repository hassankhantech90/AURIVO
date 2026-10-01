import 'package:aurivo/features/seller/domain/entities/seller_insights.dart';
import 'package:aurivo/features/seller/presentation/seller_insights_page.dart';
import 'package:aurivo/features/seller/providers/seller_insights_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _payload = <String, dynamic>{
  'views': 2,
  'orders': 5,
  'units_sold': 5,
  'revenue': '604996.00',
  'wishlist_adds': 4,
  'conversion_pct': 250.0,
  'top_products': [
    {'product_id': 'p1', 'title': 'Solitaire Ring', 'units': 4, 'revenue': 559996},
  ],
  'daily_revenue': [
    {'day': '2026-10-01', 'revenue': 0},
    {'day': '2026-10-02', 'revenue': 45000},
  ],
  'low_stock': [
    {
      'product_id': 'p2',
      'title': 'Pearl Studs',
      'sku': 'PS-1',
      'available': 0,
      'threshold': 2,
    },
  ],
};

void main() {
  test('parses the payload; conversion hidden while views < orders', () {
    final i = SellerInsights.fromMap(_payload);
    expect(i.revenue, 604996);
    expect(i.topProducts.single.title, 'Solitaire Ring');
    expect(i.lowStock.single.available, 0);
    expect(i.dailyRevenue.length, 2);
    expect(i.hasMeaningfulConversion, isFalse); // 2 views, 5 orders

    final later = SellerInsights.fromMap({
      ..._payload,
      'views': 400,
      'conversion_pct': 1.3,
    });
    expect(later.hasMeaningfulConversion, isTrue);
  });

  testWidgets('renders tiles, low stock, top products and switches window', (
    tester,
  ) async {
    final requested = <int?>[];
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sellerInsightsLoaderProvider.overrideWithValue((days) async {
            requested.add(days);
            return SellerInsights.fromMap(_payload);
          }),
        ],
        child: const MaterialApp(home: SellerInsightsPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('PKR 604,996'), findsOneWidget);
    expect(find.text('—'), findsOneWidget); // conversion not yet meaningful
    expect(find.textContaining('Out of stock'), findsOneWidget);
    expect(find.text('Solitaire Ring'), findsOneWidget);
    expect(requested, [30]);

    await tester.tap(find.text('All time'));
    await tester.pump();
    await tester.pump();
    expect(requested, [30, null]);
  });
}
