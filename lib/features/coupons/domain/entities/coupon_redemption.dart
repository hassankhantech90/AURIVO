import '../../../../core/utils/db_parsing.dart';

/// A coupon redemption record (`public.coupon_redemptions`), returned by the
/// `redeem_coupon` RPC.
///
/// The [discountAmount] is computed and written server-side; the client treats
/// it as authoritative and never derives it locally.
class CouponRedemption {
  const CouponRedemption({
    required this.id,
    required this.couponId,
    required this.profileId,
    this.orderId,
    required this.discountAmount,
    this.currency = 'PKR',
    this.redeemedAt,
  });

  final String id;
  final String couponId;
  final String profileId;
  final String? orderId;
  final double discountAmount;
  final String currency;
  final DateTime? redeemedAt;

  factory CouponRedemption.fromMap(Map<String, dynamic> map) {
    return CouponRedemption(
      id: map['id'] as String,
      couponId: map['coupon_id'] as String,
      profileId: map['profile_id'] as String,
      orderId: map['order_id'] as String?,
      discountAmount: parseDouble(map['discount_amount']),
      currency: map['currency'] as String? ?? 'PKR',
      redeemedAt: parseTimestamp(map['redeemed_at']),
    );
  }
}
