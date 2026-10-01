import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/seller/presentation/seller_team_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubDb extends SupabaseDatabaseService {
  _StubDb() : super(supabaseService: const SupabaseService());

  final List<(String, Map<String, dynamic>)> calls = [];
  List<Map<String, dynamic>> team = [
    {
      'id': 's1',
      'full_name': 'Ayesha Khan',
      'email': 'ayesha@example.com',
      'can_catalog': true,
      'can_orders': false,
      'revoked_at': null,
    },
  ];

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    calls.add((functionName, params));
    return functionName == 'my_seller_staff' ? team : null;
  }
}

void main() {
  testWidgets('lists staff, toggles a permission and adds by email', (
    tester,
  ) async {
    final db = _StubDb();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sellerTeamApiProvider.overrideWithValue(SellerTeamApi(db))],
        child: const MaterialApp(home: SellerTeamPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayesha Khan'), findsOneWidget);
    await tester.tap(find.text('Orders & quotes'));
    await tester.pumpAndSettle();
    expect(
      db.calls.firstWhere((c) => c.$1 == 'update_seller_staff').$2,
      containsPair('p_orders', true),
    );

    await tester.tap(find.text('Add staff'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bilal@example.com');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    final add = db.calls.firstWhere((c) => c.$1 == 'add_seller_staff').$2;
    expect(add['p_email'], 'bilal@example.com');
    expect(add['p_catalog'], isTrue);
    expect(add['p_messages'], isFalse);
  });
}
