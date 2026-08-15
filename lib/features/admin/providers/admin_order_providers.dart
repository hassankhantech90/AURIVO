import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../orders/domain/entities/order.dart';
import '../../orders/domain/entities/order_detail.dart';
import '../data/repositories/supabase_admin_order_repository.dart';
import '../domain/repositories/admin_order_repository.dart';
import 'admin_providers.dart' show AdminListState, AdminStatus;

/// Repository binding (lazy service — stays test-safe without an initialized
/// Supabase client).
final adminOrderRepositoryProvider = Provider<AdminOrderRepository>((ref) {
  return SupabaseAdminOrderRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

// Orders list -----------------------------------------------------------------

final adminOrdersProvider =
    StateNotifierProvider<AdminOrdersNotifier, AdminListState<Order>>((ref) {
      return AdminOrdersNotifier(ref.watch(adminOrderRepositoryProvider));
    });

class AdminOrdersNotifier extends StateNotifier<AdminListState<Order>> {
  AdminOrdersNotifier(this._repository)
    : super(const AdminListState<Order>());

  final AdminOrderRepository _repository;
  String? _statusFilter;

  String? get statusFilter => _statusFilter;

  Future<void> load({String? status, bool setFilter = false}) async {
    if (setFilter) _statusFilter = status;
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      state = AdminListState(
        status: AdminStatus.success,
        data: await _repository.listOrders(status: _statusFilter),
      );
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }
}

// Order detail (by id) --------------------------------------------------------

final adminOrderDetailProvider =
    StateNotifierProvider.family<
      AdminOrderDetailNotifier,
      AsyncValue<OrderDetail>,
      String
    >((ref, orderId) {
      return AdminOrderDetailNotifier(
        repository: ref.watch(adminOrderRepositoryProvider),
        orderId: orderId,
      );
    });

class AdminOrderDetailNotifier extends StateNotifier<AsyncValue<OrderDetail>> {
  AdminOrderDetailNotifier({
    required AdminOrderRepository repository,
    required String orderId,
  }) : _repository = repository,
       _orderId = orderId,
       super(const AsyncLoading());

  final AdminOrderRepository _repository;
  final String _orderId;

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _repository.getOrder(_orderId));
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> advanceStatus(String status, {String? notes}) => _mutate(
    () => _repository.advanceStatus(
      orderId: _orderId,
      status: status,
      notes: notes,
    ),
  );

  Future<String?> setPaymentStatus(String status) => _mutate(
    () => _repository.setPaymentStatus(orderId: _orderId, status: status),
  );

  Future<String?> cancel({String? reason}) =>
      _mutate(() => _repository.cancelOrder(orderId: _orderId, reason: reason));
}
