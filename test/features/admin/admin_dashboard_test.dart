import 'package:aurivo/features/admin/domain/entities/admin_dashboard_stats.dart';
import 'package:aurivo/features/admin/presentation/widgets/admin_dashboard_section.dart';
import 'package:aurivo/features/admin/providers/admin_dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the RPC payload, including the daily series', () {
    final s = AdminDashboardStats.fromMap({
      'gmv': '604996.00',
      'orders': 7,
      'completed_orders': 2,
      'pending_fulfilment': 3,
      'pending_products': 1,
      'pending_sellers': 2,
      'pending_businesses': 0,
      'daily_gmv': [
        {'day': '2026-10-01', 'gmv': 0},
        {'day': '2026-10-02', 'gmv': '1500.5'},
      ],
    });
    expect(s.gmv, 604996);
    expect(s.orders, 7);
    expect(s.moderationQueue, 3);
    expect(s.dailyGmv.last.$2, 1500.5);
    expect(s.dailyGmv.first.$1, DateTime(2026, 10, 1));
  });

  testWidgets('shows tiles and switches the window', (tester) async {
    final requested = <int?>[];
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminStatsLoaderProvider.overrideWithValue((days) async {
            requested.add(days);
            return AdminDashboardStats(
              gmv: 604996,
              orders: days == 7 ? 1 : 7,
              activeSellers: 2,
              dailyGmv: [(DateTime(2026, 10, 1), 0), (DateTime(2026, 10, 2), 5)],
            );
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AdminDashboardSection()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('PKR 604,996'), findsOneWidget);
    expect(find.text('Active sellers'), findsOneWidget);
    expect(find.text('GMV — last 14 days'), findsOneWidget);
    expect(requested, [30]);

    await tester.tap(find.text('7 days'));
    await tester.pump();
    await tester.pump();
    expect(requested, [30, 7]);
  });
}
