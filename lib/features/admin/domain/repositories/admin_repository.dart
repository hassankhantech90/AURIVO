import '../../../profile/domain/entities/business_profile.dart';
import '../../../profile/domain/entities/seller_profile.dart';
import '../../../seller/domain/entities/seller_product.dart';

/// Contract for the admin moderation console.
///
/// Every read/write relies on the existing admin RLS (the `OR has_role('admin')`
/// arm of the owner/seller policies); non-admins are denied server-side. The
/// moderation_hardening triggers additionally reserve product approval and store
/// verification to admins. Implementations map failures to the shared `Failure`.
abstract class AdminRepository {
  /// Whether the current user holds the `admin` role (via `has_role`).
  Future<bool> isAdmin();

  /// Seller stores awaiting verification (`verification_status = 'pending'`).
  Future<List<SellerProfile>> getPendingSellers();

  /// Sets a store's verification status (`verified` / `rejected` / `suspended`).
  Future<void> setSellerVerification({
    required String sellerId,
    required String status,
  });

  /// Business (B2B) buyer profiles awaiting verification
  /// (`verification_status = 'pending'`).
  Future<List<BusinessProfile>> getPendingBusinesses();

  /// Sets a business profile's verification status
  /// (`verified` / `rejected` / `suspended`).
  Future<void> setBusinessVerification({
    required String businessId,
    required String status,
  });

  /// Products awaiting moderation (`status = 'pending'`).
  Future<List<SellerProduct>> getPendingProducts();

  /// Sets a product's moderation status (`approved` / `rejected`).
  Future<void> setProductStatus({
    required String productId,
    required String status,
  });
}
