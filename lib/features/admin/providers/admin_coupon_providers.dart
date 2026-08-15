import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../coupons/domain/entities/coupon_redemption.dart';
import '../data/repositories/supabase_admin_coupon_repository.dart';
import '../domain/entities/admin_coupon.dart';
import '../domain/repositories/admin_coupon_repository.dart';
import 'admin_providers.dart' show AdminListState, AdminStatus;

/// Repository binding (lazy service — stays test-safe without an initialized
/// Supabase client).
final adminCouponRepositoryProvider = Provider<AdminCouponRepository>((ref) {
  return SupabaseAdminCouponRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

final adminCouponsProvider =
    StateNotifierProvider<AdminCouponsNotifier, AdminListState<AdminCoupon>>((
      ref,
    ) {
      return AdminCouponsNotifier(ref.watch(adminCouponRepositoryProvider));
    });

class AdminCouponsNotifier extends StateNotifier<AdminListState<AdminCoupon>> {
  AdminCouponsNotifier(this._repository)
    : super(const AdminListState<AdminCoupon>());

  final AdminCouponRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      state = AdminListState(
        status: AdminStatus.success,
        data: await _repository.listCoupons(),
      );
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }

  /// Creates or updates a coupon, then reloads. Returns null on success or a
  /// user-facing error message.
  Future<String?> save({
    String? id,
    required String code,
    required String name,
    String? description,
    required String discountType,
    required double discountValue,
    required double minimumOrderAmount,
    double? maximumDiscountAmount,
    int? usageLimit,
    required int perUserLimit,
    DateTime? startsAt,
    DateTime? expiresAt,
    required String status,
  }) async {
    try {
      if (id == null) {
        await _repository.createCoupon(
          code: code,
          name: name,
          description: description,
          discountType: discountType,
          discountValue: discountValue,
          minimumOrderAmount: minimumOrderAmount,
          maximumDiscountAmount: maximumDiscountAmount,
          usageLimit: usageLimit,
          perUserLimit: perUserLimit,
          startsAt: startsAt,
          expiresAt: expiresAt,
          status: status,
        );
      } else {
        await _repository.updateCoupon(
          id: id,
          code: code,
          name: name,
          description: description,
          discountType: discountType,
          discountValue: discountValue,
          minimumOrderAmount: minimumOrderAmount,
          maximumDiscountAmount: maximumDiscountAmount,
          clearMaximumDiscount: maximumDiscountAmount == null,
          usageLimit: usageLimit,
          clearUsageLimit: usageLimit == null,
          perUserLimit: perUserLimit,
          startsAt: startsAt,
          clearStartsAt: startsAt == null,
          expiresAt: expiresAt,
          clearExpiresAt: expiresAt == null,
          status: status,
        );
      }
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> setStatus(String id, String status) async {
    try {
      await _repository.setStatus(id: id, status: status);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> remove(String id) async {
    try {
      await _repository.deleteCoupon(id);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}

/// Redemption records for a coupon (admin oversight).
final adminCouponRedemptionsProvider =
    FutureProvider.family<List<CouponRedemption>, String>((ref, couponId) {
      return ref
          .watch(adminCouponRepositoryProvider)
          .listRedemptions(couponId);
    });
