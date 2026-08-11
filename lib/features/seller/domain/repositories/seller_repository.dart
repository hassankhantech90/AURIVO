import '../../../products/domain/entities/product.dart';
import '../../../profile/domain/entities/seller_profile.dart';

/// Contract for the buyer-facing seller storefront (read-only).
///
/// Every read relies on the existing RLS for visibility: only `verified`,
/// non-deleted sellers and their `approved`, non-deleted products are publicly
/// readable. It never bypasses security and performs no writes.
///
/// Implementations must never surface raw Supabase exceptions; all failures are
/// mapped to the shared `Failure` type.
abstract class SellerRepository {
  /// Verified seller storefronts, newest first.
  Future<List<SellerProfile>> getVerifiedSellers({int limit, int offset});

  /// A single verified seller by its unique [slug], or null if none is visible.
  Future<SellerProfile?> getSellerBySlug(String slug);

  /// A single verified seller by id, or null if none is visible.
  Future<SellerProfile?> getSellerById(String id);

  /// Approved products belonging to [sellerId], newest first.
  Future<List<Product>> getSellerProducts(
    String sellerId, {
    int limit,
    int offset,
  });
}
