import '../entities/coupon.dart';
import '../entities/coupon_redemption.dart';

/// Contract for coupon reads and redemption.
///
/// Redemption goes exclusively through the `redeem_coupon` SECURITY DEFINER
/// RPC — this repository only forwards the coupon `code` and the `order_id`.
/// It never computes, sends, or trusts a client-side discount; the server is
/// authoritative for the discount and the resulting order totals.
///
/// Implementations must never surface raw Supabase exceptions; all failures are
/// mapped to the shared `Failure` type (preserving the RPC's `P0001` messages).
abstract class CouponRepository {
  /// Publicly visible, active coupons (RLS restricts to active + in-window).
  Future<List<Coupon>> getActiveCoupons({int limit, int offset});

  /// Applies [code] to [orderId] via the `redeem_coupon` RPC and returns the
  /// resulting redemption. The server validates the coupon, enforces all
  /// limits, computes the discount, and updates the order totals.
  Future<CouponRedemption> redeem({
    required String code,
    required String orderId,
  });
}
