import '../../../coupons/domain/entities/coupon_redemption.dart';
import '../entities/admin_coupon.dart';

/// Contract for admin coupon management. Relies on `coupons_admin_all` and
/// `coupon_redemptions_admin_update_delete` (`has_role('admin')`); non-admins
/// are denied server-side. "Delete" is a soft delete (sets `deleted_at` and
/// archives) so it stays reversible. `used_count` is server-managed by the
/// `redeem_coupon` RPC and never written here. Failures map to `Failure`.
abstract class AdminCouponRepository {
  Future<List<AdminCoupon>> listCoupons();

  Future<AdminCoupon> createCoupon({
    required String code,
    required String name,
    String? description,
    required String discountType,
    required double discountValue,
    double minimumOrderAmount = 0,
    double? maximumDiscountAmount,
    int? usageLimit,
    int perUserLimit = 1,
    DateTime? startsAt,
    DateTime? expiresAt,
    String status = 'draft',
  });

  Future<AdminCoupon> updateCoupon({
    required String id,
    String? code,
    String? name,
    String? description,
    String? discountType,
    double? discountValue,
    double? minimumOrderAmount,
    double? maximumDiscountAmount,
    bool clearMaximumDiscount = false,
    int? usageLimit,
    bool clearUsageLimit = false,
    int? perUserLimit,
    DateTime? startsAt,
    bool clearStartsAt = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    String? status,
  });

  /// Quick status transition (`active` / `paused` / `draft` / `archived`).
  Future<void> setStatus({required String id, required String status});

  /// Soft-deletes (archives) a coupon.
  Future<void> deleteCoupon(String id);

  /// Redemption records for a coupon (admin oversight), newest first.
  Future<List<CouponRedemption>> listRedemptions(String couponId);
}
