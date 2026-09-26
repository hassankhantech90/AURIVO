import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/domain/repositories/category_repository.dart';
import '../../categories/providers/category_providers.dart';
import '../../products/domain/entities/product.dart';
import '../../products/domain/repositories/product_repository.dart';
import '../../products/providers/catalog_state.dart';
import '../../products/providers/product_providers.dart';

/// Explore catalogue state, independent of Home's [productListProvider] (I1) and
/// aware of category-subtree filtering (I2). Unfiltered by default; when given a
/// root category it resolves the visible subtree and filters products against
/// the whole set — both steps inside one [CatalogRunner] so any failure maps to
/// the shared catalogue failure state.
final exploreProductsProvider =
    StateNotifierProvider<ExploreProductsNotifier, CatalogState<List<Product>>>((
      ref,
    ) {
      return ExploreProductsNotifier(
        products: ref.watch(productRepositoryProvider),
        categories: ref.watch(categoryRepositoryProvider),
      );
    });

class ExploreProductsNotifier
    extends StateNotifier<CatalogState<List<Product>>> {
  ExploreProductsNotifier({
    required ProductRepository products,
    required CategoryRepository categories,
  }) : _products = products,
       _categories = categories,
       super(const CatalogState<List<Product>>()) {
    _runner = CatalogRunner<List<Product>>(() => state, (value) => state = value);
  }

  final ProductRepository _products;
  final CategoryRepository _categories;
  late final CatalogRunner<List<Product>> _runner;

  /// Loads the catalogue for Explore. With [rootCategoryId] null this is the
  /// full newest catalogue; otherwise it filters to that root category's
  /// visible subtree (root + all descendants). [material] filters by metal and
  /// [search] is a title contains-match; both compose with the category filter
  /// (AND).
  Future<void> load({String? rootCategoryId, String? material, String? search}) {
    return _runner.run(() async {
      if (rootCategoryId == null) {
        return _products.getProducts(material: material, search: search);
      }
      final ids = await _categories.descendantCategoryIds(rootCategoryId);
      return _products.getProducts(
        categoryIds: ids,
        material: material,
        search: search,
      );
    });
  }
}
