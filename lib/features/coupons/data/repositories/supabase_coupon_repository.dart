import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../domain/entities/coupon.dart';
import '../../domain/entities/coupon_redemption.dart';
import '../../domain/repositories/coupon_repository.dart';
import '../coupon_failure_mapper.dart';

/// Supabase-backed [CouponRepository].
///
/// Redemption delegates entirely to the `redeem_coupon` SECURITY DEFINER RPC,
/// forwarding only the coupon code and order id. The RPC validates the coupon,
/// enforces every limit, computes the discount, and updates the order totals —
/// this class computes nothing and sends no monetary value.
class SupabaseCouponRepository implements CouponRepository {
  SupabaseCouponRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _couponsTable = 'coupons';

  @override
  Future<List<Coupon>> getActiveCoupons({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // RLS restricts visibility to active, in-window, non-deleted coupons.
      final rows = await _database.list(
        table: _couponsTable,
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
        offset: offset,
      );
      return rows.map(Coupon.fromMap).toList();
    } catch (error) {
      throw CouponFailureMapper.map(error);
    }
  }

  @override
  Future<CouponRedemption> redeem({
    required String code,
    required String orderId,
  }) async {
    try {
      final result = await _database.rpc(
        functionName: 'redeem_coupon',
        params: {'p_code': code.trim(), 'p_order_id': orderId},
      );
      final row = _asRow(result);
      if (row == null) {
        throw const Failure(
          message: 'Could not apply the coupon. Please try again.',
        );
      }
      return CouponRedemption.fromMap(row);
    } catch (error) {
      throw CouponFailureMapper.map(error);
    }
  }

  /// `redeem_coupon` returns a `coupon_redemptions` row. PostgREST may surface
  /// it as a single object or a single-row list.
  Map<String, dynamic>? _asRow(Object? result) {
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    return null;
  }
}
