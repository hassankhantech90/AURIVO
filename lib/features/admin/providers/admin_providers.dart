import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../authentication/providers/session_provider.dart';
import '../../profile/domain/entities/business_profile.dart';
import '../../profile/domain/entities/seller_profile.dart';
import '../../seller/domain/entities/seller_product.dart';
import '../data/repositories/supabase_admin_repository.dart';
import '../domain/repositories/admin_repository.dart';

/// Repository binding (lazy service — stays test-safe without an initialized
/// Supabase client).
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return SupabaseAdminRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

/// Whether the current user is an admin. Gates the entire admin console.
///
/// Watches the signed-in identity so it recomputes on every account switch —
/// otherwise a cached `true` from an admin session would leak the admin console
/// to the next (non-admin) user who signs in. When signed out it short-circuits
/// to `false` without an RPC.
final isAdminProvider = FutureProvider<bool>((ref) {
  final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
  if (userId == null) return Future.value(false);
  return ref.watch(adminRepositoryProvider).isAdmin();
});

enum AdminStatus { initial, loading, success, failure }

class AdminListState<T> {
  const AdminListState({
    this.status = AdminStatus.initial,
    this.data = const [],
    this.message,
  });

  final AdminStatus status;
  final List<T> data;
  final String? message;

  bool get isLoading => status == AdminStatus.loading;

  AdminListState<T> copyWith({
    AdminStatus? status,
    List<T>? data,
    String? message,
    bool clearMessage = false,
  }) {
    return AdminListState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

// Seller verification queue ---------------------------------------------------

final pendingSellersProvider =
    StateNotifierProvider<
      PendingSellersNotifier,
      AdminListState<SellerProfile>
    >((ref) {
      return PendingSellersNotifier(ref.watch(adminRepositoryProvider));
    });

class PendingSellersNotifier
    extends StateNotifier<AdminListState<SellerProfile>> {
  PendingSellersNotifier(this._repository)
    : super(const AdminListState<SellerProfile>());

  final AdminRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      final sellers = await _repository.getPendingSellers();
      state = AdminListState(status: AdminStatus.success, data: sellers);
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }

  /// Approves (`verified`) or rejects a store, then drops it from the queue.
  /// Returns null on success or a user-facing error message.
  Future<String?> setVerification(String sellerId, String status) async {
    try {
      await _repository.setSellerVerification(
        sellerId: sellerId,
        status: status,
      );
      state = state.copyWith(
        data: state.data.where((s) => s.id != sellerId).toList(),
      );
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}

// Business verification queue -------------------------------------------------

final pendingBusinessesProvider =
    StateNotifierProvider<
      PendingBusinessesNotifier,
      AdminListState<BusinessProfile>
    >((ref) {
      return PendingBusinessesNotifier(ref.watch(adminRepositoryProvider));
    });

class PendingBusinessesNotifier
    extends StateNotifier<AdminListState<BusinessProfile>> {
  PendingBusinessesNotifier(this._repository)
    : super(const AdminListState<BusinessProfile>());

  final AdminRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      final businesses = await _repository.getPendingBusinesses();
      state = AdminListState(status: AdminStatus.success, data: businesses);
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }

  /// Approves (`verified`) or rejects a business, then drops it from the queue.
  /// Returns null on success or a user-facing error message.
  Future<String?> setVerification(String businessId, String status) async {
    try {
      await _repository.setBusinessVerification(
        businessId: businessId,
        status: status,
      );
      state = state.copyWith(
        data: state.data.where((b) => b.id != businessId).toList(),
      );
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}

// Product moderation queue ----------------------------------------------------

final pendingProductsProvider =
    StateNotifierProvider<
      PendingProductsNotifier,
      AdminListState<SellerProduct>
    >((ref) {
      return PendingProductsNotifier(ref.watch(adminRepositoryProvider));
    });

class PendingProductsNotifier
    extends StateNotifier<AdminListState<SellerProduct>> {
  PendingProductsNotifier(this._repository)
    : super(const AdminListState<SellerProduct>());

  final AdminRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      final products = await _repository.getPendingProducts();
      state = AdminListState(status: AdminStatus.success, data: products);
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }

  /// Approves (`approved`) or rejects a product, then drops it from the queue.
  /// Returns null on success or a user-facing error message.
  Future<String?> setStatus(String productId, String status) async {
    try {
      await _repository.setProductStatus(productId: productId, status: status);
      state = state.copyWith(
        data: state.data.where((p) => p.id != productId).toList(),
      );
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
