import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_seller_order_repository.dart';
import '../domain/entities/seller_order_detail.dart';
import '../domain/entities/seller_order_summary.dart';
import '../domain/repositories/seller_order_repository.dart';
import 'seller_providers.dart' show SellerDataState, SellerViewStatus;

/// Repository binding (lazy service — stays test-safe without an initialized
/// Supabase client).
final sellerOrderRepositoryProvider = Provider<SellerOrderRepository>((ref) {
  return SupabaseSellerOrderRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

// Seller orders inbox ---------------------------------------------------------

final sellerOrdersProvider =
    StateNotifierProvider<
      SellerOrdersNotifier,
      SellerDataState<List<SellerOrderSummary>>
    >((ref) {
      return SellerOrdersNotifier(ref.watch(sellerOrderRepositoryProvider));
    });

class SellerOrdersNotifier
    extends StateNotifier<SellerDataState<List<SellerOrderSummary>>> {
  SellerOrdersNotifier(this._repository)
    : super(const SellerDataState<List<SellerOrderSummary>>());

  final SellerOrderRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: SellerViewStatus.loading, clearMessage: true);
    try {
      final orders = await _repository.getOrders();
      state = SellerDataState(status: SellerViewStatus.success, data: orders);
    } catch (error) {
      state = state.copyWith(
        status: SellerViewStatus.failure,
        message: error.toString(),
      );
    }
  }
}

// Seller order detail (by order id) -------------------------------------------

final sellerOrderDetailProvider =
    StateNotifierProvider.family<
      SellerOrderDetailNotifier,
      SellerDataState<SellerOrderDetail>,
      String
    >((ref, orderId) {
      return SellerOrderDetailNotifier(
        repository: ref.watch(sellerOrderRepositoryProvider),
        orderId: orderId,
      );
    });

class SellerOrderDetailNotifier
    extends StateNotifier<SellerDataState<SellerOrderDetail>> {
  SellerOrderDetailNotifier({
    required SellerOrderRepository repository,
    required String orderId,
  }) : _repository = repository,
       _orderId = orderId,
       super(const SellerDataState<SellerOrderDetail>());

  final SellerOrderRepository _repository;
  final String _orderId;

  Future<void> load() async {
    state = state.copyWith(status: SellerViewStatus.loading, clearMessage: true);
    try {
      final detail = await _repository.getOrder(_orderId);
      state = SellerDataState(status: SellerViewStatus.success, data: detail);
    } catch (error) {
      state = state.copyWith(
        status: SellerViewStatus.failure,
        message: error.toString(),
      );
    }
  }

  /// Appends [status] (`packed`/`shipped`) to the order history, then reloads.
  /// Returns null on success or a user-facing error message.
  Future<String?> advanceStatus(String status) async {
    try {
      await _repository.advanceStatus(orderId: _orderId, status: status);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  /// Creates or updates the order's shipment, then reloads. Returns null on
  /// success or a user-facing error message.
  Future<String?> saveShipment({
    required String status,
    String? courier,
    String? trackingNumber,
    String? trackingUrl,
  }) async {
    try {
      await _repository.saveShipment(
        orderId: _orderId,
        status: status,
        courier: courier,
        trackingNumber: trackingNumber,
        trackingUrl: trackingUrl,
      );
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
