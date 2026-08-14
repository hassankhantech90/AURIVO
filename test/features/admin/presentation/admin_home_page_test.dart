import 'package:aurivo/features/admin/presentation/admin_home_page.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required bool admin}) => ProviderScope(
  overrides: [isAdminProvider.overrideWith((ref) async => admin)],
  child: const MaterialApp(home: AdminHomePage()),
);

void main() {
  testWidgets('non-admins see an unauthorized state', (tester) async {
    await tester.pumpWidget(_wrap(admin: false));
    await tester.pumpAndSettle();
    expect(find.text('Not authorized'), findsOneWidget);
    expect(find.text('Seller verifications'), findsNothing);
  });

  testWidgets('admins see the moderation menu', (tester) async {
    await tester.pumpWidget(_wrap(admin: true));
    await tester.pumpAndSettle();
    expect(find.text('Seller verifications'), findsOneWidget);
    expect(find.text('Product moderation'), findsOneWidget);
  });
}
