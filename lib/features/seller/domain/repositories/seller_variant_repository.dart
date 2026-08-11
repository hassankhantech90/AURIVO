import '../entities/seller_variant.dart';

/// Contract for seller-side product variant management.
///
/// Writes are direct, RLS-governed operations scoped to the seller who owns the
/// parent product (`product_variants_seller_all_own`). Ownership is enforced by
/// the database. Failures are mapped to the shared `Failure` type.
abstract class SellerVariantRepository {
  /// Variants of [productId] (excluding soft-deleted).
  Future<List<SellerVariant>> getVariants(String productId);

  Future<SellerVariant> createVariant(String productId, VariantDraft draft);

  Future<SellerVariant> updateVariant(String id, VariantDraft draft);

  /// Soft-deletes a variant (sets `deleted_at`).
  Future<void> softDelete(String id);
}
