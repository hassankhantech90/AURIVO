import 'package:aurivo/features/coupons/domain/entities/coupon.dart';
import 'package:aurivo/features/coupons/domain/entities/coupon_redemption.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Coupon.fromMap parses a percentage coupon', () {
    final coupon = Coupon.fromMap({
      'id': 'c1',
      'code': 'SAVE10',
      'name': '10% off',
      'description': 'Ten percent',
      'discount_type': 'percentage',
      'discount_value': 10,
      'minimum_order_amount': 1000,
      'maximum_discount_amount': 500,
      'expires_at': '2026-12-31T00:00:00Z',
      'status': 'active',
    });

    expect(coupon.code, 'SAVE10');
    expect(coupon.isPercentage, isTrue);
    expect(coupon.discountValue, 10);
    expect(coupon.minimumOrderAmount, 1000);
    expect(coupon.maximumDiscountAmount, 500);
    expect(coupon.expiresAt, isNotNull);
  });

  test('Coupon.fromMap parses a fixed-amount coupon with defaults', () {
    final coupon = Coupon.fromMap({
      'id': 'c2',
      'code': 'FLAT200',
      'name': 'PKR 200 off',
      'discount_type': 'fixed_amount',
      'discount_value': 200,
    });

    expect(coupon.isPercentage, isFalse);
    expect(coupon.minimumOrderAmount, 0);
    expect(coupon.maximumDiscountAmount, isNull);
    expect(coupon.description, isNull);
  });

  test('CouponRedemption.fromMap parses the server row', () {
    final redemption = CouponRedemption.fromMap({
      'id': 'red-1',
      'coupon_id': 'c1',
      'profile_id': 'p1',
      'order_id': 'o1',
      'discount_amount': 250,
      'currency': 'PKR',
      'redeemed_at': '2026-01-01T00:00:00Z',
    });

    expect(redemption.discountAmount, 250);
    expect(redemption.orderId, 'o1');
    expect(redemption.currency, 'PKR');
    expect(redemption.redeemedAt, isNotNull);
  });
}
