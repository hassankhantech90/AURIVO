import '../../../categories/domain/entities/category.dart';
import '../../../products/domain/entities/brand.dart';
import '../entities/product_draft.dart';
import '../entities/seller_product.dart';

/// Contract for seller-side product management.
///
/// All writes are direct, RLS-governed table operations scoped to the seller
/// who owns the product (`products_seller_*_own` and friends). Ownership is
/// enforced by the database; the seller's `seller_profile_id` is resolved
/// server-side (via the current profile), never supplied by the UI. Category
/// and brand lists are read from the admin-curated catalogue.
///
/// Implementations must never surface raw Supabase exceptions; all failures are
/// mapped to the shared `Failure` type.
abstract class SellerProductRepository {
  /// The current user's seller-profile id, or null if they are not a seller.
  Future<String?> mySellerProfileId();

  /// The seller's own products (all statuses, excluding soft-deleted).
  Future<List<SellerProduct>> getMyProducts({int limit, int offset});

  /// A single owned product with its assigned category ids.
  Future<SellerProductDetail> getProduct(String id);

  /// Creates a product owned by the current seller (status defaults to draft).
  Future<SellerProduct> createProduct(ProductDraft draft);

  /// Updates an owned product and syncs its category assignments.
  Future<SellerProduct> updateProduct(String id, ProductDraft draft);

  /// Publishes (`approved`) or unpublishes (`draft`) an owned product.
  Future<SellerProduct> setPublished(String id, bool published);

  /// Soft-deletes an owned product (sets `deleted_at`).
  Future<void> softDelete(String id);

  /// Active brands (admin-curated) for assignment.
  Future<List<Brand>> getBrands();

  /// Active categories (admin-curated) for assignment.
  Future<List<Category>> getCategories();
}
