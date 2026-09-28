import '../../../products/domain/entities/price_tier.dart';
import '../entities/price_tier_draft.dart';

/// Contract for seller-side wholesale price-tier management.
///
/// Writes are direct, RLS-governed operations scoped to the seller who owns the
/// parent product (`product_price_tiers_seller_all_own`). Ownership is enforced
/// by the database, never supplied by the UI. Tiers have no soft-delete, so
/// removal is a hard delete. Failures map to the shared `Failure` type.
abstract class SellerTierRepository {
  /// Tiers of [productId], ascending by minimum quantity.
  Future<List<PriceTier>> getTiers(String productId);

  Future<PriceTier> createTier(String productId, PriceTierDraft draft);

  Future<PriceTier> updateTier(String id, PriceTierDraft draft);

  Future<void> deleteTier(String id);
}
