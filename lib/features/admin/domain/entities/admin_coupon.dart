import '../../../../core/utils/db_parsing.dart';

/// Admin-facing coupon (`public.coupons`) with the full management surface —
/// including `usageLimit`, `perUserLimit` and the server-managed `usedCount`
/// that the buyer-facing `Coupon` entity intentionally omits.
class AdminCoupon {
  const AdminCoupon({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.minimumOrderAmount = 0,
    this.maximumDiscountAmount,
    this.usageLimit,
    this.perUserLimit = 1,
    this.usedCount = 0,
    this.startsAt,
    this.expiresAt,
    this.status = 'draft',
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

  /// Total redemptions allowed across all users (null = unlimited).
  final int? usageLimit;
  final int perUserLimit;

  /// Server-managed by `redeem_coupon`; read-only for the admin console.
  final int usedCount;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final String status;

  bool get isPercentage => discountType == 'percentage';

  factory AdminCoupon.fromMap(Map<String, dynamic> map) {
    return AdminCoupon(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      discountType: map['discount_type'] as String,
      discountValue: parseDouble(map['discount_value']),
      minimumOrderAmount: parseDouble(map['minimum_order_amount']),
      maximumDiscountAmount: parseDoubleOrNull(map['maximum_discount_amount']),
      usageLimit: map['usage_limit'] == null
          ? null
          : parseInt(map['usage_limit']),
      perUserLimit: parseInt(map['per_user_limit']),
      usedCount: parseInt(map['used_count']),
      startsAt: parseTimestamp(map['starts_at']),
      expiresAt: parseTimestamp(map['expires_at']),
      status: map['status'] as String? ?? 'draft',
    );
  }
}
