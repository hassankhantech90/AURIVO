import 'package:aurivo/features/products/domain/entities/catalog_filters.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_sort.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:aurivo/features/products/providers/recently_viewed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Product _p(String id) => Product(
  id: id,
  sellerId: 's1',
  title: 'Item $id',
  slug: id,
  jewelleryType: 'ring',
  basePrice: 1000,
);

/// Returns the requested ids in a DIFFERENT (catalogue) order, minus hidden.
class _Repo implements ProductRepository {
  _Repo({this.hidden = const {}});
  final Set<String> hidden;
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
    lastFilters = filters;
    final ids = [...?filters.ids]..sort();
    return [for (final id in ids) if (!hidden.contains(id)) _p(id)];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('record puts the newest first, de-duplicates and caps', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = RecentlyViewedNotifier();
    await _settle();

    for (var i = 0; i < RecentlyViewedNotifier.maxItems + 2; i++) {
      await notifier.record('p$i');
    }
    await notifier.record('p5'); // revisit moves it to the front

    expect(notifier.state.first, 'p5');
    expect(notifier.state.length, RecentlyViewedNotifier.maxItems);
    expect(notifier.state.where((id) => id == 'p5').length, 1);
  });

  test('persists and restores across launches', () async {
    SharedPreferences.setMockInitialValues({});
    final first = RecentlyViewedNotifier();
    await _settle();
    await first.record('a');
    await first.record('b');

    final next = RecentlyViewedNotifier();
    await _settle();
    expect(next.state, ['b', 'a']);
  });

  test('products come back in recency order, hidden ones dropped', () async {
    SharedPreferences.setMockInitialValues({
      'products.recently_viewed': ['c', 'a', 'b'],
    });
    final repo = _Repo(hidden: {'a'});
    final container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(recentlyViewedProvider);
    await _settle();
    final products = await container.read(
      recentlyViewedProductsProvider.future,
    );

    expect(products.map((p) => p.id), ['c', 'b']);
    expect(repo.lastFilters!.ids, ['c', 'a', 'b']);
  });

  test('nothing viewed -> no catalogue query', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _Repo();
    final container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await _settle();
    expect(await container.read(recentlyViewedProductsProvider.future), isEmpty);
    expect(repo.lastFilters, isNull);
  });
}
