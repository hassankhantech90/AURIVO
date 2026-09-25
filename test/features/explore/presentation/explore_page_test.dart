import 'dart:async';

import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/theme/theme.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/categories/domain/repositories/category_repository.dart';
import 'package:aurivo/features/categories/providers/category_providers.dart';
import 'package:aurivo/features/explore/presentation/explore_page.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_sort.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:aurivo/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:aurivo/features/wishlist/providers/wishlist_providers.dart';
import 'package:aurivo/shared/widgets/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Presentation coverage for the REAL ExplorePage. Repository/subtree behaviour
/// and I1/I2 regressions live in explore_category_filter_test / explore_isolation_test.

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({this.products = const [], this.error, this.hang});
  final List<Product> products;
  final Object? error;
  final Completer<List<Product>>? hang;
  int calls = 0;

  @override
  Future<List<Product>> getProducts({
    int limit = 20,
    int offset = 0,
    String? brandId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    String? material,
    ProductSort sort = ProductSort.newest,
  }) {
    calls++;
    if (hang != null) return hang!.future;
    if (error != null) return Future<List<Product>>.error(error!);
    return Future<List<Product>>.value(products);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Unfiltered Explore never resolves a subtree, so this is never invoked.
class _NoCategoryRepository implements CategoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyWishlistRepository implements WishlistRepository {
  int calls = 0;
  @override
  Future<Set<String>> getWishlistedProductIds() async {
    calls++;
    return <String>{};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthedSession extends SessionNotifier {
  _AuthedSession()
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      ) {
    state = const SessionState(status: SessionStatus.authenticated);
  }
}

Product _product(String id) => Product(
  id: id,
  sellerId: 'seller-1',
  title: 'Ring $id',
  slug: 'ring-$id',
  jewelleryType: 'ring',
  basePrice: 1000,
);

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Widget _explore({
  required _FakeProductRepository products,
  _SpyWishlistRepository? wishlist,
  Override? session,
  ThemeData? theme,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ExplorePage()),
      GoRoute(
        path: '/product/:id',
        builder: (_, s) => Scaffold(body: Text('PRODUCT_${s.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      productRepositoryProvider.overrideWithValue(products),
      categoryRepositoryProvider.overrideWithValue(_NoCategoryRepository()),
      if (wishlist != null)
        wishlistRepositoryProvider.overrideWithValue(wishlist),
      ?session,
    ],
    child: MaterialApp.router(routerConfig: router, theme: theme),
  );
}

void main() {
  testWidgets('A. renders the Explore app bar, a product, and no Home actions', (
    tester,
  ) async {
    _bigView(tester);
    await tester.pumpWidget(
      _explore(products: _FakeProductRepository(products: [_product('p1')])),
    );
    await _settle(tester);

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Ring p1'), findsOneWidget);
    // Explore has no Home-style app-bar actions/badges.
    expect(find.byTooltip('Messages'), findsNothing);
    expect(find.byTooltip('Notifications'), findsNothing);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('B. shows the loading indicator during the initial load', (
    tester,
  ) async {
    await tester.pumpWidget(
      _explore(products: _FakeProductRepository(hang: Completer<List<Product>>())),
    );
    await _settle(tester);

    expect(find.byType(LoadingIndicator), findsOneWidget);
  });

  testWidgets('C. renders the empty state for an empty catalogue', (
    tester,
  ) async {
    await tester.pumpWidget(
      _explore(products: _FakeProductRepository(products: const [])),
    );
    await _settle(tester);

    expect(find.text('No products found'), findsOneWidget);
  });

  testWidgets('D. renders the error state with Retry on failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _explore(products: _FakeProductRepository(error: Exception('boom'))),
    );
    await _settle(tester);

    // Production error UI is ErrorStateWidget (title + mapped message + Retry).
    // The 'Could not load the catalogue.' fallback only shows on a null message.
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('E. renders multiple products in the grid', (tester) async {
    _bigView(tester);
    await tester.pumpWidget(
      _explore(
        products: _FakeProductRepository(
          products: [_product('p1'), _product('p2')],
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Ring p1'), findsOneWidget);
    expect(find.text('Ring p2'), findsOneWidget);
  });

  testWidgets('F. tapping a product navigates to /product/:id', (tester) async {
    _bigView(tester);
    await tester.pumpWidget(
      _explore(products: _FakeProductRepository(products: [_product('p1')])),
    );
    await _settle(tester);

    await tester.tap(find.text('Ring p1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('PRODUCT_p1'), findsOneWidget);
  });

  testWidgets('G. guest mount loads the catalogue but not the wishlist', (
    tester,
  ) async {
    final products = _FakeProductRepository(products: const []);
    final wishlist = _SpyWishlistRepository();
    await tester.pumpWidget(
      _explore(products: products, wishlist: wishlist), // no session => guest
    );
    await _settle(tester);

    expect(products.calls, 1);
    expect(wishlist.calls, 0);
  });

  testWidgets('H. authenticated mount loads the catalogue and the wishlist', (
    tester,
  ) async {
    final products = _FakeProductRepository(products: const []);
    final wishlist = _SpyWishlistRepository();
    await tester.pumpWidget(
      _explore(
        products: products,
        wishlist: wishlist,
        session: sessionProvider.overrideWith((ref) => _AuthedSession()),
      ),
    );
    await _settle(tester);

    expect(products.calls, 1);
    expect(wishlist.calls, 1);
  });

  testWidgets('L. dark mode renders the app bar and a product without error', (
    tester,
  ) async {
    _bigView(tester);
    await tester.pumpWidget(
      _explore(
        products: _FakeProductRepository(products: [_product('p1')]),
        theme: AppTheme.dark,
      ),
    );
    await _settle(tester);

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Ring p1'), findsOneWidget);
  });

  // (M) Small-screen / large-text safety is intentionally NOT a widget test
  // here: the repo has no stable small-viewport test convention, and a probe at
  // ~375px surfaced a product-card layout overflow that must be verified and
  // (if real) fixed on its own — not inside a test commit. Deferred to
  // physical-device QA / a separate finding.
}
