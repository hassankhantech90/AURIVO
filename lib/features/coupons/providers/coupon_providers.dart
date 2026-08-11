import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_coupon_repository.dart';
import '../domain/entities/coupon_redemption.dart';
import '../domain/repositories/coupon_repository.dart';

/// Repository binding for coupons (lazy services — stays test-safe without an
/// initialized Supabase client).
final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  const service = SupabaseService();
  return SupabaseCouponRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

enum CouponStatus { idle, applying, success, failure }

/// State for a single coupon application. On success [redemption] carries the
/// server-computed result (used only to confirm; the authoritative totals live
/// on the order, which the UI reloads).
class CouponState {
  const CouponState({
    this.status = CouponStatus.idle,
    this.redemption,
    this.message,
  });

  final CouponStatus status;
  final CouponRedemption? redemption;
  final String? message;

  bool get isApplying => status == CouponStatus.applying;
  bool get isApplied => status == CouponStatus.success;
}

final couponProvider = StateNotifierProvider<CouponNotifier, CouponState>((
  ref,
) {
  return CouponNotifier(ref.watch(couponRepositoryProvider));
});

class CouponNotifier extends StateNotifier<CouponState> {
  CouponNotifier(this._repository) : super(const CouponState());

  final CouponRepository _repository;

  /// Applies [code] to [orderId] via the RPC. Returns null on success, or a
  /// user-facing error message (the server's P0001 text) on failure. Never
  /// throws — callers can safely continue the order flow when a coupon fails.
  Future<String?> apply({required String code, required String orderId}) async {
    if (state.isApplying) return null;
    state = const CouponState(status: CouponStatus.applying);
    try {
      final redemption = await _repository.redeem(code: code, orderId: orderId);
      state = CouponState(status: CouponStatus.success, redemption: redemption);
      return null;
    } catch (error) {
      state = CouponState(
        status: CouponStatus.failure,
        message: error.toString(),
      );
      return error.toString();
    }
  }

  void reset() => state = const CouponState();
}
