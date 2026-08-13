import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/profile/domain/repositories/profile_repository.dart';
import 'package:aurivo/features/profile/providers/profile_providers.dart';
import 'package:aurivo/features/seller/presentation/seller_onboarding_page.dart';
import 'package:aurivo/shared/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeProfileRepository implements ProfileRepository {
  int createCalls = 0;
  Map<String, dynamic>? lastCreateArgs;

  @override
  Future<SellerProfile?> getSellerProfile() async => null;

  @override
  Future<SellerProfile> createSellerProfile({
    required String storeName,
    required String slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
  }) async {
    createCalls++;
    lastCreateArgs = {'storeName': storeName, 'slug': slug, 'city': city};
    return SellerProfile(
      id: 'sp1',
      profileId: 'p1',
      storeName: storeName,
      slug: slug,
      city: city,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(ProfileRepository repo) {
  final router = GoRouter(
    initialLocation: '/sell',
    routes: [
      GoRoute(
        path: '/sell',
        builder: (_, _) => const SellerOnboardingPage(),
      ),
      GoRoute(
        path: '/seller-studio',
        builder: (_, _) => const Scaffold(body: Text('STUDIO')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('rejects a too-short store name without calling create', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeProfileRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'A');
    await tester.tap(find.widgetWithText(LoadingButton, 'Create store'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 0);
    expect(find.textContaining('at least 2 characters'), findsOneWidget);
  });

  testWidgets('creates the store and opens Seller Studio', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeProfileRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Store name only; slug auto-derives.
    await tester.enterText(find.byType(TextField).at(0), 'Zainab Jewellers');
    await tester.tap(find.widgetWithText(LoadingButton, 'Create store'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(repo.lastCreateArgs!['slug'], 'zainab-jewellers');
    expect(find.text('STUDIO'), findsOneWidget);
  });
}
