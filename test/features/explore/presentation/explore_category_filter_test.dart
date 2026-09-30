import 'package:aurivo/features/categories/domain/repositories/category_repository.dart';
import 'package:aurivo/features/categories/providers/category_providers.dart';
import 'package:aurivo/features/explore/presentation/explore_page.dart';
import 'package:aurivo/features/products/domain/entities/catalog_filters.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_sort.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// I2 Explore behaviour: unfiltered by default; filtered to a root category's
/// resolved subtree when a category id is provided.

class _TreeCategoryRepository implements CategoryRepository {
  _TreeCategoryRepository(this.descendants);
  final Map<String, List<String>> descendants;
  final List<String> resolvedRoots = [];

  @override
  Future<List<String>> descendantCategoryIds(String rootId) async {
    resolvedRoots.add(rootId);
    return descendants[rootId] ?? [rootId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CatalogProductRepository implements ProductRepository {
  _CatalogProductRepository({
    this.unfiltered = const [],
    this.bySet = const {},
    this.failFirstFiltered = false,
  });
  final List<Product> unfiltered;
  final Map<String, List<Product>> bySet; // key = categoryIds joined by ','
  bool failFirstFiltered;

  bool unfilteredRequested = false;
  int filteredCalls = 0;
  List<String>? lastCategoryIds;
  String? lastMaterial;
  String? lastSearch;
  ProductSort? lastSort;
  CatalogFilters? lastFilters;

  @override
  Future<List<Product>> getProducts({
    int limit = 20,
    int offset = 0,
    String? brandId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    String? material,
    String? search,
    bool wholesaleOnly = false,
    ProductSort sort = ProductSort.newest,
    CatalogFilters filters = const CatalogFilters(),
  }) async {
    lastMaterial = material;
    lastSearch = search;
    lastSort = sort;
    lastFilters = filters;
    if (categoryIds == null) {
      unfilteredRequested = true;
      return unfiltered;
    }
    filteredCalls++;
    lastCategoryIds = categoryIds;
    if (failFirstFiltered && filteredCalls == 1) {
      throw Exception('boom');
    }
    return bySet[categoryIds.join(',')] ?? const [];
  }

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

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

List<Override> _overrides(
  _CatalogProductRepository products,
  _TreeCategoryRepository categories,
) => [
  productRepositoryProvider.overrideWithValue(products),
  categoryRepositoryProvider.overrideWithValue(categories),
];

/// Lets a modal sheet open/close; the grid has endless animations, so
/// pumpAndSettle would never settle.
Future<void> _sheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('D. direct Explore loads the unfiltered catalogue', (
    tester,
  ) async {
    _bigView(tester);
    final products = _CatalogProductRepository(
      unfiltered: [_product('UNFILTERED')],
    );
    final categories = _TreeCategoryRepository(const {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(products, categories),
        child: const MaterialApp(home: ExplorePage()),
      ),
    );
    await _settle(tester);

    expect(find.text('Ring UNFILTERED'), findsOneWidget);
    expect(products.unfilteredRequested, isTrue);
    expect(products.lastCategoryIds, isNull); // no category-set filter
    expect(categories.resolvedRoots, isEmpty); // no subtree resolution
  });

  testWidgets('D1. the filter sheet applies sort, metal, purity and price', (
    tester,
  ) async {
    _bigView(tester);
    final products = _CatalogProductRepository(unfiltered: [_product('A')]);
    final categories = _TreeCategoryRepository(const {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(products, categories),
        child: const MaterialApp(home: ExplorePage()),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byTooltip('Sort & filter'));
    await _sheet(tester);
    await tester.tap(find.text('Price: low to high'));
    await tester.tap(find.text('Silver'));
    await tester.tap(find.text('925'));
    await tester.tap(find.text('25k – 100k'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await _sheet(tester);

    expect(products.lastSort, ProductSort.priceLowToHigh);
    expect(products.lastMaterial, 'Silver');
    expect(products.lastFilters!.purity, '925');
    expect(products.lastFilters!.minPrice, 25000);
    expect(products.lastFilters!.maxPrice, 100000);
    expect(find.text('4'), findsOneWidget); // active-filter badge

    // Reset clears everything.
    await tester.tap(find.byTooltip('Sort & filter'));
    await _sheet(tester);
    await tester.tap(find.text('Reset'));
    await _sheet(tester);
    expect(products.lastSort, ProductSort.newest);
    expect(products.lastMaterial, isNull);
    expect(products.lastFilters!.isEmpty, isTrue);
  });

  testWidgets('D2. a metal filter passes material and titles the surface', (
    tester,
  ) async {
    _bigView(tester);
    final products = _CatalogProductRepository(
      unfiltered: [_product('GOLD')],
    );
    final categories = _TreeCategoryRepository(const {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(products, categories),
        child: const MaterialApp(home: ExplorePage(material: 'Gold')),
      ),
    );
    await _settle(tester);

    expect(products.lastMaterial, 'Gold'); // metal reaches the repository
    expect(products.lastCategoryIds, isNull); // no category-set filter
    expect(find.text('Gold'), findsOneWidget); // app-bar title is the metal
    expect(find.text('Ring GOLD'), findsOneWidget);
  });

  testWidgets('D3. a route search query seeds the field and reaches the repo', (
    tester,
  ) async {
    _bigView(tester);
    final products = _CatalogProductRepository(
      unfiltered: [_product('MATCH')],
    );
    final categories = _TreeCategoryRepository(const {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(products, categories),
        child: const MaterialApp(home: ExplorePage(search: 'ring')),
      ),
    );
    await _settle(tester);

    expect(products.lastSearch, 'ring'); // query reaches the repository
    expect(products.lastCategoryIds, isNull); // no category-set filter
    expect(find.text('Explore'), findsOneWidget); // title stays "Explore"
    expect(find.text('ring'), findsOneWidget); // search field seeded with query
    expect(find.text('Ring MATCH'), findsOneWidget);
  });

  testWidgets('D4. submitting the search field refines the results', (
    tester,
  ) async {
    _bigView(tester);
    final products = _CatalogProductRepository(
      unfiltered: [_product('MATCH')],
    );
    final categories = _TreeCategoryRepository(const {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(products, categories),
        child: const MaterialApp(home: ExplorePage()),
      ),
    );
    await _settle(tester);
    expect(products.lastSearch, isNull); // initial load had no query

    await tester.enterText(find.byType(SearchBar), 'pendant');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(products.lastSearch, 'pendant'); // refined query reaches the repo
  });

  testWidgets('D5. typing debounces, then live-searches after a pause', (
    tester,
  ) async {
    _bigView(tester);
    final products = _CatalogProductRepository(
      unfiltered: [_product('MATCH')],
    );
    final categories = _TreeCategoryRepository(const {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(products, categories),
        child: const MaterialApp(home: ExplorePage()),
      ),
    );
    await _settle(tester);
    expect(products.lastSearch, isNull);

    await tester.enterText(find.byType(SearchBar), 'ring');
    await tester.pump(const Duration(milliseconds: 100)); // still within debounce
    expect(products.lastSearch, isNull); // not yet fired

    await tester.pump(const Duration(milliseconds: 400)); // past the debounce
    expect(products.lastSearch, 'ring'); // live search fired once paused
  });

  testWidgets('E. filtered Explore resolves the subtree and filters products', (
    tester,
  ) async {
    _bigView(tester);
    final subtree = ['root', 'childA', 'grandchild', 'childB'];
    final products = _CatalogProductRepository(
      bySet: {subtree.join(','): [_product('SUBTREE')]},
    );
    final categories = _TreeCategoryRepository({'root': subtree});

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(products, categories),
        child: const MaterialApp(home: ExplorePage(categoryId: 'root')),
      ),
    );
    await _settle(tester);

    expect(categories.resolvedRoots, ['root']);
    expect(products.lastCategoryIds, subtree);
    expect(find.text('Ring SUBTREE'), findsOneWidget);
  });

  testWidgets('F. pull-to-refresh preserves the root category', (tester) async {
    _bigView(tester);
    final subtree = ['root', 'childA'];
    final products = _CatalogProductRepository(
      bySet: {subtree.join(','): [_product('SUBTREE')]},
    );
    final categories = _TreeCategoryRepository({'root': subtree});

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(products, categories),
        child: const MaterialApp(home: ExplorePage(categoryId: 'root')),
      ),
    );
    await _settle(tester);
    expect(categories.resolvedRoots, ['root']);

    // Invoke the RefreshIndicator's callback directly (same _load path).
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await _settle(tester);

    expect(categories.resolvedRoots, ['root', 'root']); // same root re-resolved
    expect(products.lastCategoryIds, subtree);
  });

  testWidgets('G. Retry after a failure preserves the root category', (
    tester,
  ) async {
    _bigView(tester);
    final subtree = ['root', 'childA'];
    final products = _CatalogProductRepository(
      bySet: {subtree.join(','): [_product('SUBTREE')]},
      failFirstFiltered: true,
    );
    final categories = _TreeCategoryRepository({'root': subtree});

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(products, categories),
        child: const MaterialApp(home: ExplorePage(categoryId: 'root')),
      ),
    );
    await _settle(tester);

    // First load failed -> error state with Retry.
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await _settle(tester);

    expect(categories.resolvedRoots, ['root', 'root']); // same root on retry
    expect(find.text('Ring SUBTREE'), findsOneWidget); // now succeeds
  });

  testWidgets('H. switching category A -> B loads B, not stale A', (
    tester,
  ) async {
    _bigView(tester);
    final products = _CatalogProductRepository(
      bySet: {
        'a': [_product('A_RESULT')],
        'b': [_product('B_RESULT')],
      },
    );
    final categories = _TreeCategoryRepository({
      'catA': ['a'],
      'catB': ['b'],
    });
    // Shared container so the app-scoped exploreProductsProvider persists across
    // the two Explore instances (as it would across navigation).
    final container = ProviderContainer(
      overrides: _overrides(products, categories),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ExplorePage(key: ValueKey('a'), categoryId: 'catA'),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Ring A_RESULT'), findsOneWidget);

    // Open Explore for category B as a DISTINCT page instance (as push would
    // create) — a different key forces a fresh State + initState _load.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ExplorePage(key: ValueKey('b'), categoryId: 'catB'),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Ring B_RESULT'), findsOneWidget);
    expect(find.text('Ring A_RESULT'), findsNothing); // no stale A content
  });
}
