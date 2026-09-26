import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/supabase/supabase_storage_service.dart';
import '../../../core/utils/failure.dart';
import '../data/primary_image_resolver.dart';
import '../data/repositories/supabase_product_repository.dart';
import '../domain/entities/brand.dart';
import '../domain/entities/price_tier.dart';
import '../domain/entities/product.dart';
import '../domain/entities/product_detail.dart';
import '../domain/entities/product_sort.dart';
import '../domain/repositories/product_repository.dart';
import 'catalog_state.dart';

/// Repository binding for the product catalogue (lazy service — stays test-safe
/// without an initialized Supabase client).
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  const database = SupabaseDatabaseService(supabaseService: SupabaseService());
  return SupabaseProductRepository(
    database: database,
    imageResolver: const PrimaryImageResolver(
      database: database,
      storage: SupabaseStorageService(supabaseService: SupabaseService()),
    ),
  );
});

// Product list ---------------------------------------------------------------

final productListProvider =
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

/// Product-detail state scoped per product id. Each id owns its own notifier and
/// state, so opening product B never observes product A's detail (no stale
/// flash, no cross-product contamination). autoDispose frees a product's state
/// once its page is gone; reopening simply reloads.
final productDetailProvider =
    StateNotifierProvider.autoDispose
        .family<ProductDetailNotifier, CatalogState<ProductDetail>, String>((
          ref,
          productId,
        ) {
          return ProductDetailNotifier(
            ref.watch(productRepositoryProvider),
            productId,
          );
        });

class ProductDetailNotifier extends StateNotifier<CatalogState<ProductDetail>> {
  ProductDetailNotifier(this._repository, this._productId)
    : super(const CatalogState<ProductDetail>()) {
    _runner = CatalogRunner<ProductDetail>(
      () => state,
      (value) => state = value,
    );
  }

  final ProductRepository _repository;
  final String _productId;
  late final CatalogRunner<ProductDetail> _runner;

  /// Loads the detail for this notifier's bound product id. The id is fixed at
  /// construction, so a page can never accidentally load a different product.
  Future<void> load() {
    return _runner.run(() async {
      final detail = await _repository.getProductDetail(_productId);
      if (detail == null) {
        throw const Failure(message: 'This product is no longer available.');
      }
      return detail;
    });
  }
}

// Price tiers ----------------------------------------------------------------

/// Wholesale price tiers for a product, scoped per id and auto-disposed. Empty
/// for products without tiered pricing. Read-only — no notifier needed.
final productPriceTiersProvider = FutureProvider.autoDispose
    .family<List<PriceTier>, String>((ref, productId) {
      return ref.watch(productRepositoryProvider).getProductPriceTiers(productId);
    });

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
