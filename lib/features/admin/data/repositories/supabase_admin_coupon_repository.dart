import '../../../../core/supabase/supabase_database_service.dart';
import '../../../coupons/domain/entities/coupon_redemption.dart';
import '../../domain/entities/admin_coupon.dart';
import '../../domain/repositories/admin_coupon_repository.dart';
import '../admin_failure_mapper.dart';

/// Supabase-backed [AdminCouponRepository]. Uses the `coupons_admin_all` /
/// `coupon_redemptions_admin_update_delete` RLS arm; never bypasses security.
/// Lists drop soft-deleted rows client-side (the shared query helper supports
/// only equality filters, not `IS NULL`).
class SupabaseAdminCouponRepository implements AdminCouponRepository {
  SupabaseAdminCouponRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const _coupons = 'coupons';
  static const _redemptions = 'coupon_redemptions';

  String? _iso(DateTime? dt) => dt?.toUtc().toIso8601String();

  @override
  Future<List<AdminCoupon>> listCoupons() async {
    try {
      final rows = await _database.list(
        table: _coupons,
        orderBy: 'created_at',
        ascending: false,
      );
      return rows
          .where((r) => r['deleted_at'] == null)
          .map(AdminCoupon.fromMap)
          .toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
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
  }) async {
    try {
      final row = await _database.insert(
        table: _coupons,
        values: {
          'code': code.trim().toUpperCase(),
          'name': name.trim(),
          'description': ?description,
          'discount_type': discountType,
          'discount_value': discountValue,
          'minimum_order_amount': minimumOrderAmount,
          'maximum_discount_amount': ?maximumDiscountAmount,
          'usage_limit': ?usageLimit,
          'per_user_limit': perUserLimit,
          'starts_at': ?_iso(startsAt),
          'expires_at': ?_iso(expiresAt),
          'status': status,
        },
      );
      return AdminCoupon.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
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
  }) async {
    try {
      final values = <String, dynamic>{
        'code': ?code?.trim().toUpperCase(),
        'name': ?name?.trim(),
        'description': ?description?.trim(),
        'discount_type': ?discountType,
        'discount_value': ?discountValue,
        'minimum_order_amount': ?minimumOrderAmount,
        if (clearMaximumDiscount || maximumDiscountAmount != null)
          'maximum_discount_amount': maximumDiscountAmount,
        if (clearUsageLimit || usageLimit != null) 'usage_limit': usageLimit,
        'per_user_limit': ?perUserLimit,
        if (clearStartsAt || startsAt != null) 'starts_at': _iso(startsAt),
        if (clearExpiresAt || expiresAt != null) 'expires_at': _iso(expiresAt),
        'status': ?status,
      };
      final row = await _database.update(
        table: _coupons,
        values: values,
        matchColumn: 'id',
        matchValue: id,
      );
      return AdminCoupon.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> setStatus({required String id, required String status}) async {
    try {
      await _database.update(
        table: _coupons,
        values: {'status': status},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteCoupon(String id) async {
    try {
      await _database.update(
        table: _coupons,
        values: {
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'archived',
        },
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<List<CouponRedemption>> listRedemptions(String couponId) async {
    try {
      final rows = await _database.list(
        table: _redemptions,
        filters: {'coupon_id': couponId},
        orderBy: 'redeemed_at',
        ascending: false,
      );
      return rows.map(CouponRedemption.fromMap).toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }
}
