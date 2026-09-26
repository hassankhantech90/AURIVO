import '../../../../core/supabase/supabase_database_service.dart';
import '../../domain/entities/attribute.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/price_tier.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_detail.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/entities/product_sort.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/repositories/product_repository.dart';
import '../catalog_failure_mapper.dart';
import '../primary_image_resolver.dart';

/// Supabase-backed read-only [ProductRepository].
///
/// Every query relies on the existing RLS for visibility (approved/active/
/// non-deleted rows only) — it never bypasses security. Buyer-facing variant
/// columns are selected explicitly so internal inventory data is not exposed.
class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository({
    required SupabaseDatabaseService database,
    required PrimaryImageResolver imageResolver,
  }) : _database = database,
       _imageResolver = imageResolver;

  final SupabaseDatabaseService _database;
  final PrimaryImageResolver _imageResolver;

  static const String _productsTable = 'products';
  static const String _productCategoriesTable = 'product_categories';
  static const String _productImagesTable = 'product_images';
  static const String _productVariantsTable = 'product_variants';
  static const String _productPriceTiersTable = 'product_price_tiers';
  static const String _brandsTable = 'brands';
  static const String _attributesTable = 'attributes';
  static const String _attributeValuesTable = 'attribute_values';

  // Buyer-facing variant columns only (no sku/barcode/stock).
  static const String _variantColumns =
      'id, product_id, price, currency, compare_price, weight_grams, is_active';

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
    ProductSort sort = ProductSort.newest,
  }) async {
    try {
      final filters = <String, Object?>{
        'brand_id': ?brandId,
        'featured': ?featured,
        'material': ?material,
      };
      final whereIn = <String, List<Object>>{};
      // categoryIds (a category-set / subtree filter) takes precedence over the
      // single categoryId; they are never combined.
      if (categoryIds != null) {
        if (categoryIds.isEmpty) return const [];
        final ids = await _productIdsInCategories(categoryIds);
        if (ids.isEmpty) return const [];
        whereIn['id'] = ids;
      } else if (categoryId != null) {
        final ids = await _productIdsInCategory(categoryId);
        if (ids.isEmpty) return const [];
        whereIn['id'] = ids;
      }

      final (orderBy, ascending) = _sortOrder(sort);
      final rows = await _database.list(
        table: _productsTable,
        filters: filters,
        whereIn: whereIn,
        ilikeColumn: 'title',
        ilikeQuery: search,
        orderBy: orderBy,
        ascending: ascending,
        limit: limit,
        offset: offset,
      );
      final products = rows.map(Product.fromMap).toList();
      return _imageResolver.enrich(products);
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<Product?> getProductById(String id) async {
    try {
      final rows = await _database.list(
        table: _productsTable,
        filters: {'id': id},
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Product.fromMap(rows.first);
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<List<Product>> getProductsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _database.list(
        table: _productsTable,
        whereIn: {'id': List<Object>.from(ids)},
        limit: ids.length,
      );
      final products = rows.map(Product.fromMap).toList();
      return _imageResolver.enrich(products);
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<ProductDetail?> getProductDetail(String id) async {
    try {
      final product = await getProductById(id);
      if (product == null) return null;
      final images = await getProductImages(id);
      final variants = await getProductVariants(id);
      // Reuse the images already loaded above (no extra image query) and the
      // same primary-image semantic as the catalogue cards. getPublicUrl is a
      // local string build; guarded so a resolution issue degrades the hero to
      // a placeholder instead of failing the whole detail load.
      final detail = ProductDetail(
        product: product,
        images: images,
        variants: variants,
      );
      String? primaryImageUrl;
      final primary = detail.primaryImage;
      if (primary != null && primary.storagePath.isNotEmpty) {
        try {
          primaryImageUrl = _imageResolver.publicUrl(primary.storagePath);
        } catch (_) {
          primaryImageUrl = null;
        }
      }
      return ProductDetail(
        product: product.copyWith(primaryImageUrl: primaryImageUrl),
        images: images,
        variants: variants,
      );
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<List<Product>> getProductsByCategory(
    String categoryId, {
    int limit = 20,
    int offset = 0,
  }) {
    return getProducts(categoryId: categoryId, limit: limit, offset: offset);
  }

  @override
  Future<List<Product>> getProductsByBrand(
    String brandId, {
    int limit = 20,
    int offset = 0,
  }) {
    return getProducts(brandId: brandId, limit: limit, offset: offset);
  }

  @override
  Future<List<ProductImage>> getProductImages(String productId) async {
    try {
      final rows = await _database.list(
        table: _productImagesTable,
        filters: {'product_id': productId},
        orderBy: 'sort_order',
      );
      return rows.map(ProductImage.fromMap).toList();
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<List<ProductVariant>> getProductVariants(String productId) async {
    try {
      final rows = await _database.list(
        table: _productVariantsTable,
        columns: _variantColumns,
        filters: {'product_id': productId},
        orderBy: 'price',
      );
      return rows.map(ProductVariant.fromMap).toList();
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<List<PriceTier>> getProductPriceTiers(String productId) async {
    try {
      final rows = await _database.list(
        table: _productPriceTiersTable,
        filters: {'product_id': productId},
        orderBy: 'min_quantity',
      );
      return rows.map(PriceTier.fromMap).toList();
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<List<Brand>> getBrands() async {
    try {
      final rows = await _database.list(table: _brandsTable, orderBy: 'name');
      return rows.map(Brand.fromMap).toList();
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<Brand?> getBrandById(String id) async {
    try {
      final rows = await _database.list(
        table: _brandsTable,
        filters: {'id': id},
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Brand.fromMap(rows.first);
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<List<Attribute>> getAttributes({bool filterableOnly = false}) async {
    try {
      final rows = await _database.list(
        table: _attributesTable,
        filters: {if (filterableOnly) 'is_filterable': true},
        orderBy: 'name',
      );
      return rows.map(Attribute.fromMap).toList();
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<List<AttributeValue>> getAttributeValues(String attributeId) async {
    try {
      final rows = await _database.list(
        table: _attributeValuesTable,
        filters: {'attribute_id': attributeId},
        orderBy: 'sort_order',
      );
      return rows.map(AttributeValue.fromMap).toList();
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  Future<List<Object>> _productIdsInCategory(String categoryId) async {
    final rows = await _database.list(
      table: _productCategoriesTable,
      columns: 'product_id',
      filters: {'category_id': categoryId},
    );
    return rows
        .map((row) => row['product_id'])
        .whereType<Object>()
        .toList(growable: false);
  }

  /// Unique product ids assigned to ANY of [categoryIds] (subtree filter). A
  /// product mapped to multiple supplied categories is returned once.
  Future<List<Object>> _productIdsInCategories(List<String> categoryIds) async {
    final rows = await _database.list(
      table: _productCategoriesTable,
      columns: 'product_id',
      whereIn: {'category_id': List<Object>.from(categoryIds)},
    );
    return rows
        .map((row) => row['product_id'])
        .whereType<Object>()
        .toSet()
        .toList(growable: false);
  }

  (String, bool) _sortOrder(ProductSort sort) {
    switch (sort) {
      case ProductSort.newest:
        return ('created_at', false);
      case ProductSort.featured:
        return ('featured', false);
      case ProductSort.priceLowToHigh:
        return ('base_price', true);
      case ProductSort.priceHighToLow:
        return ('base_price', false);
    }
  }
}
