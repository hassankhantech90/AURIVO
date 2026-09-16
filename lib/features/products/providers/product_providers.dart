import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/failure.dart';
import '../data/repositories/supabase_product_repository.dart';
import '../domain/entities/brand.dart';
import '../domain/entities/product.dart';
import '../domain/entities/product_detail.dart';
import '../domain/entities/product_sort.dart';
import '../domain/repositories/product_repository.dart';
import 'catalog_state.dart';

/// Repository binding for the product catalogue (lazy service — stays test-safe
/// without an initialized Supabase client).
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return SupabaseProductRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

// Product list ---------------------------------------------------------------

final productListProvider =
    StateNotifierProvider<ProductListNotifier, CatalogState<List<Product>>>((
      ref,
    ) {
      return ProductListNotifier(ref.watch(productRepositoryProvider));
    });

/// Dedicated catalogue state for the Explore grid, independent of
/// [productListProvider] (which Home uses for its Featured rail). Same notifier
/// and repository — only the state instance is separate, so the two surfaces
/// never overwrite each other's products.
final exploreProductsProvider =
    StateNotifierProvider<ProductListNotifier, CatalogState<List<Product>>>((
      ref,
    ) {
      return ProductListNotifier(ref.watch(productRepositoryProvider));
    });

class ProductListNotifier extends StateNotifier<CatalogState<List<Product>>> {
  ProductListNotifier(this._repository)
    : super(const CatalogState<List<Product>>()) {
    _runner = CatalogRunner<List<Product>>(
      () => state,
      (value) => state = value,
    );
  }

  final ProductRepository _repository;
  late final CatalogRunner<List<Product>> _runner;

  Future<void> load({
    int limit = 20,
    int offset = 0,
    String? brandId,
    String? categoryId,
    bool? featured,
    ProductSort sort = ProductSort.newest,
  }) {
    return _runner.run(
      () => _repository.getProducts(
        limit: limit,
        offset: offset,
        brandId: brandId,
        categoryId: categoryId,
        featured: featured,
        sort: sort,
      ),
    );
  }

  Future<void> loadFeatured({int limit = 10}) {
    return _runner.run(
      () => _repository.getProducts(limit: limit, featured: true),
    );
  }
}

// Product detail -------------------------------------------------------------

final productDetailProvider =
    StateNotifierProvider<ProductDetailNotifier, CatalogState<ProductDetail>>((
      ref,
    ) {
      return ProductDetailNotifier(ref.watch(productRepositoryProvider));
    });

class ProductDetailNotifier extends StateNotifier<CatalogState<ProductDetail>> {
  ProductDetailNotifier(this._repository)
    : super(const CatalogState<ProductDetail>()) {
    _runner = CatalogRunner<ProductDetail>(
      () => state,
      (value) => state = value,
    );
  }

  final ProductRepository _repository;
  late final CatalogRunner<ProductDetail> _runner;

  Future<void> load(String productId) {
    return _runner.run(() async {
      final detail = await _repository.getProductDetail(productId);
      if (detail == null) {
        throw const Failure(message: 'This product is no longer available.');
      }
      return detail;
    });
  }
}

// Brands ---------------------------------------------------------------------

final brandsProvider =
    StateNotifierProvider<BrandsNotifier, CatalogState<List<Brand>>>((ref) {
      return BrandsNotifier(ref.watch(productRepositoryProvider));
    });

class BrandsNotifier extends StateNotifier<CatalogState<List<Brand>>> {
  BrandsNotifier(this._repository) : super(const CatalogState<List<Brand>>()) {
    _runner = CatalogRunner<List<Brand>>(() => state, (value) => state = value);
  }

  final ProductRepository _repository;
  late final CatalogRunner<List<Brand>> _runner;

  Future<void> load() => _runner.run(_repository.getBrands);
}
