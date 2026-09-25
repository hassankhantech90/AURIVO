import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/categories/domain/entities/category.dart';
import 'package:aurivo/features/categories/domain/repositories/category_repository.dart';
import 'package:aurivo/features/categories/providers/category_providers.dart';
import 'package:aurivo/features/explore/presentation/explore_page.dart';
import 'package:aurivo/features/explore/providers/explore_products_provider.dart';
import 'package:aurivo/features/home/presentation/home_page.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_sort.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// I1 regression: Home's Featured rail (productListProvider) and Explore's grid
/// (exploreProductsProvider) must hold independent catalogue state so neither
/// surface overwrites the other.

/// Returns different products depending on the `featured` filter, so Home's
/// loadFeatured() and Explore's load() are distinguishable.
class _RoutingProductRepository implements ProductRepository {
  _RoutingProductRepository({this.featured = const [], this.catalogue = const []});
  final List<Product> featured;
  final List<Product> catalogue;

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
  }) async {
    return featured == true ? this.featured : catalogue;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository(this.categories);
  final List<Category> categories;

  @override
  Future<List<Category>> getRootCategories() async => categories;

  @override
  Future<List<String>> descendantCategoryIds(String rootId) async => [rootId];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product _product(String id) => Product(
  id: id,
  sellerId: 'seller-1',
  title: 'Ring $id',
  slug: 'ring-$id',
  jewelleryType: 'ring',
  basePrice: 1000,
);

Category _category(String name) =>
    Category(id: name.toLowerCase(), name: name, slug: name.toLowerCase());

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  group('A. provider isolation', () {
    test('loading Explore does not change Home Featured state', () async {
      final repo = _RoutingProductRepository(
        featured: [_product('FEATURED_A')],
        catalogue: [_product('EXPLORE_B')],
      );
      final container = ProviderContainer(
        overrides: [productRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(productListProvider.notifier).loadFeatured();
      expect(container.read(productListProvider).data!.single.id, 'FEATURED_A');

      await container.read(exploreProductsProvider.notifier).load();
      expect(container.read(exploreProductsProvider).data!.single.id, 'EXPLORE_B');

      // Home Featured state is untouched by the Explore load.
      expect(container.read(productListProvider).data!.single.id, 'FEATURED_A');
    });

    test('loading Home Featured does not change Explore state', () async {
      final repo = _RoutingProductRepository(
        featured: [_product('FEATURED_A')],
        catalogue: [_product('EXPLORE_B')],
      );
      final container = ProviderContainer(
        overrides: [productRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(exploreProductsProvider.notifier).load();
      expect(container.read(exploreProductsProvider).data!.single.id, 'EXPLORE_B');

      await container.read(productListProvider.notifier).loadFeatured();
      expect(container.read(productListProvider).data!.single.id, 'FEATURED_A');

      // Explore state is untouched by the Home load.
      expect(container.read(exploreProductsProvider).data!.single.id, 'EXPLORE_B');
    });
  });

  testWidgets('B. Home -> Explore -> back keeps Home Featured intact', (
    tester,
  ) async {
    _bigView(tester);
    final repo = _RoutingProductRepository(
      featured: [_product('FEATURED_A')],
      catalogue: [_product('EXPLORE_B')],
    );
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
        GoRoute(path: AppRoutes.explore, builder: (_, _) => const ExplorePage()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          categoryRepositoryProvider.overrideWithValue(
            _FakeCategoryRepository([_category('Rings')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _settle(tester);

    expect(find.text('Ring FEATURED_A'), findsOneWidget); // Home Featured

    // Tap the category card -> pushes /explore.
    await tester.tap(find.text('Rings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);

    expect(find.text('Ring EXPLORE_B'), findsOneWidget); // Explore catalogue

    // Navigate back to Home (allow the pop transition to fully complete so the
    // outgoing Explore route is removed from the tree).
    GoRouter.of(tester.element(find.byType(ExplorePage))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    // Home Featured is intact; Explore's catalogue never leaked into it.
    expect(find.text('Ring FEATURED_A'), findsOneWidget);
    expect(find.text('Ring EXPLORE_B'), findsNothing);
  });

  testWidgets('C. ExplorePage renders exploreProductsProvider, not '
      'productListProvider', (tester) async {
    _bigView(tester);
    final repo = _RoutingProductRepository(
      featured: [_product('HOME_ONLY')],
      catalogue: [_product('EXPLORE_ONLY')],
    );
    final container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Seed Home's provider with a distinct product.
    await container.read(productListProvider.notifier).loadFeatured();
    expect(container.read(productListProvider).data!.single.id, 'HOME_ONLY');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ExplorePage()),
      ),
    );
    await _settle(tester);

    // Explore shows its own catalogue, not Home's seeded product.
    expect(find.text('Ring EXPLORE_ONLY'), findsOneWidget);
    expect(find.text('Ring HOME_ONLY'), findsNothing);
    // Rendering Explore did not mutate Home's provider.
    expect(container.read(productListProvider).data!.single.id, 'HOME_ONLY');
  });
}
