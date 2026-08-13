import 'package:aurivo/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('profile page prompts guests to sign in', (tester) async {
    // Session is unauthenticated in tests (no Supabase config).
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const ProfilePage())],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to AURIVO'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
