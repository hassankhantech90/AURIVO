import '../../../../core/utils/db_parsing.dart';

/// A publicly visible, active coupon (`public.coupons`).
///
/// Only `active`, in-window coupons are readable under RLS. The discount is
/// never computed on the client — these fields are for display/marketing only;
/// the `redeem_coupon` RPC is authoritative for the actual discount applied.
class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.minimumOrderAmount = 0,
    this.maximumDiscountAmount,
    this.startsAt,
    this.expiresAt,
    this.status = 'active',
  });

  final String id;
  final String code;
  final String name;
  final String? description;

  /// `percentage` or `fixed_amount`.
  final String discountType;
  final double discountValue;
  final double minimumOrderAmount;
  final double? maximumDiscountAmount;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final String status;

  bool get isPercentage => discountType == 'percentage';

  factory Coupon.fromMap(Map<String, dynamic> map) {
    return Coupon(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      discountType: map['discount_type'] as String,
      discountValue: parseDouble(map['discount_value']),
      minimumOrderAmount: parseDouble(map['minimum_order_amount']),
      maximumDiscountAmount: parseDoubleOrNull(map['maximum_discount_amount']),
      startsAt: parseTimestamp(map['starts_at']),
      expiresAt: parseTimestamp(map['expires_at']),
      status: map['status'] as String? ?? 'active',
    );
  }
}
