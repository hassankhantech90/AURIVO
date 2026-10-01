import 'package:aurivo/features/admin/data/staff_mfa_service.dart';
import 'package:aurivo/features/admin/domain/entities/admin_dashboard_stats.dart';
import 'package:aurivo/features/admin/presentation/admin_home_page.dart';
import 'package:aurivo/features/admin/providers/admin_dashboard_providers.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required bool admin}) => ProviderScope(
  overrides: [
    staffMfaStateProvider.overrideWith((ref) async => StaffMfaState.satisfied),
    isAdminProvider.overrideWith((ref) async => admin),
    adminStatsLoaderProvider.overrideWithValue(
      (days) async => const AdminDashboardStats(),
    ),
  ],
  child: const MaterialApp(home: AdminHomePage()),
);

void main() {
  testWidgets('non-admins see an unauthorized state', (tester) async {
    await tester.pumpWidget(_wrap(admin: false));
    await tester.pumpAndSettle();
    expect(find.text('Not authorized'), findsOneWidget);
    expect(find.text('Seller verifications'), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('admins see the dashboard and the moderation menu', (
    tester,
  ) async {
    // The dashboard sits above the menu — use a tall view so the lazily
    // built menu items are on screen.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(admin: true));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Seller verifications'), findsOneWidget);
    expect(find.text('Product moderation'), findsOneWidget);
    expect(find.text('Dispute centre'), findsOneWidget);
  });

  testWidgets('support staff see only their tools', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          staffMfaStateProvider.overrideWith(
            (ref) async => StaffMfaState.satisfied,
          ),
          staffAccessProvider.overrideWith(
            (ref) async => const StaffAccess(isSupport: true),
          ),
        ],
        child: const MaterialApp(home: AdminHomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff console'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Dispute centre'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Product moderation'), findsNothing);
    expect(find.text('Audit log'), findsNothing);
  });

  testWidgets('finance staff see the dashboard and audit log', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          staffMfaStateProvider.overrideWith(
            (ref) async => StaffMfaState.satisfied,
          ),
          staffAccessProvider.overrideWith(
            (ref) async => const StaffAccess(isFinance: true),
          ),
          adminStatsLoaderProvider.overrideWithValue(
            (days) async => const AdminDashboardStats(),
          ),
        ],
        child: const MaterialApp(home: AdminHomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Audit log'), findsOneWidget);
    expect(find.text('Support'), findsNothing);
    expect(find.text('Users & roles'), findsNothing);
  });
}
