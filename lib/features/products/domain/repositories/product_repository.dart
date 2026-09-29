import '../entities/attribute.dart';
import '../entities/brand.dart';
import '../entities/price_tier.dart';
import '../entities/product.dart';
import '../entities/product_detail.dart';
import '../entities/product_image.dart';
import '../entities/product_sort.dart';
import '../entities/product_variant.dart';

/// Read-only contract for the public product catalogue. Implementations rely
/// entirely on the existing RLS (only approved, non-deleted products and their
/// active variants/images are returned) and must throw the shared `Failure`
/// type rather than raw Supabase exceptions.
abstract class ProductRepository {
  /// When [categoryIds] is provided it takes precedence over [categoryId] and
  /// matches products in ANY of the given categories; a non-null empty list
  /// yields no products. [categoryId] is kept for backward compatibility.
  ///
  /// [material] filters by the product's metal (e.g. 'Gold', 'Silver') and
  /// composes with the other filters (AND). [search] is a case-insensitive
  /// contains-match on the product title and composes with the other filters.
  /// When [wholesaleOnly] is true, only products that offer wholesale (tiered)
  /// pricing are returned; it composes with the other filters.
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
  });

  Future<Product?> getProductById(String id);

  /// Products for the given [ids] (order not guaranteed). Returns an empty list
  /// for empty input. Only ids visible under the catalogue RLS are returned, so
  /// unavailable/removed products are simply omitted.
  Future<List<Product>> getProductsByIds(List<String> ids);

  /// Product with its images and variants for the detail screen.
  Future<ProductDetail?> getProductDetail(String id);

  Future<List<Product>> getProductsByCategory(
    String categoryId, {
    int limit = 20,
    int offset = 0,
  });

  Future<List<Product>> getProductsByBrand(
    String brandId, {
    int limit = 20,
    int offset = 0,
  });

  Future<List<ProductImage>> getProductImages(String productId);

  Future<List<ProductVariant>> getProductVariants(String productId);

  /// Wholesale price tiers for [productId], ascending by minimum quantity.
  /// Empty when the product has no tiered pricing.
  Future<List<PriceTier>> getProductPriceTiers(String productId);

  Future<List<Brand>> getBrands();

  Future<Brand?> getBrandById(String id);

  Future<List<Attribute>> getAttributes({bool filterableOnly = false});

  Future<List<AttributeValue>> getAttributeValues(String attributeId);
}
