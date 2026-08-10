import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_order_repository.dart';
import '../domain/entities/order.dart';
import '../domain/entities/order_detail.dart';
import '../domain/repositories/order_repository.dart';

/// Repository binding for the orders module (lazy services — stays test-safe
/// without an initialized Supabase client).
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  const service = SupabaseService();
  return SupabaseOrderRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

enum OrderViewStatus { initial, loading, success, failure }

/// Generic state container for an orders-module resource, mirroring the profile
/// module's style.
class OrderDataState<T> {
  const OrderDataState({
    this.status = OrderViewStatus.initial,
    this.data,
    this.message,
  });

  final OrderViewStatus status;
  final T? data;
  final String? message;

  bool get isLoading => status == OrderViewStatus.loading;

  OrderDataState<T> copyWith({
    OrderViewStatus? status,
    T? data,
    String? message,
    bool clearMessage = false,
  }) {
    return OrderDataState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// Shared run helper that maps actions into loading/success/failure states.
class _Runner<T> {
  _Runner(this._read, this._write);

  final OrderDataState<T> Function() _read;
  final void Function(OrderDataState<T>) _write;

  Future<void> run(Future<T> Function() action) async {
    _write(
      _read().copyWith(status: OrderViewStatus.loading, clearMessage: true),
    );
    try {
      final data = await action();
      _write(OrderDataState<T>(status: OrderViewStatus.success, data: data));
    } catch (error) {
      _write(
        _read().copyWith(
          status: OrderViewStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }
}

// Orders list ----------------------------------------------------------------

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, OrderDataState<List<Order>>>((ref) {
      return OrdersNotifier(ref.watch(orderRepositoryProvider));
    });

class OrdersNotifier extends StateNotifier<OrderDataState<List<Order>>> {
  OrdersNotifier(this._repository)
    : super(const OrderDataState<List<Order>>()) {
    _runner = _Runner<List<Order>>(() => state, (value) => state = value);
  }

  final OrderRepository _repository;
  late final _Runner<List<Order>> _runner;

  Future<void> load() => _runner.run(() => _repository.getOrders());
}

// Order detail ---------------------------------------------------------------

/// Family keyed by order id so each order detail has its own state.
final orderDetailProvider =
    StateNotifierProvider.family<
      OrderDetailNotifier,
      OrderDataState<OrderDetail>,
      String
    >((ref, orderId) {
      return OrderDetailNotifier(ref.watch(orderRepositoryProvider), orderId);
    });

class OrderDetailNotifier extends StateNotifier<OrderDataState<OrderDetail>> {
  OrderDetailNotifier(this._repository, this._orderId)
    : super(const OrderDataState<OrderDetail>()) {
    _runner = _Runner<OrderDetail>(() => state, (value) => state = value);
  }

  final OrderRepository _repository;
  final String _orderId;
  late final _Runner<OrderDetail> _runner;

  Future<void> load() => _runner.run(() => _repository.getOrder(_orderId));

  /// Cancels the order then reloads it. Returns true on success; on failure the
  /// state carries the (P0001) message and the detail is reloaded unchanged.
  Future<bool> cancel({String? reason}) async {
    var succeeded = false;
    await _runner.run(() async {
      await _repository.cancelOrder(orderId: _orderId, reason: reason);
      succeeded = true;
      // Reflect the authoritative server state after cancelling.
      return await _repository.getOrder(_orderId);
    });
    return succeeded && state.status == OrderViewStatus.success;
  }
}
