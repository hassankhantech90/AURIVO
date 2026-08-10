import '../entities/order.dart';
import '../entities/order_detail.dart';

/// Contract for reading a buyer's orders and cancelling eligible ones.
///
/// Orders, items, status history, payments, shipments and tracking are all
/// read-only buyer projections — surfaced through RLS-scoped SELECTs. The only
/// mutation a buyer may perform is cancellation, which goes exclusively through
/// the `cancel_order` SECURITY DEFINER RPC.
///
/// Implementations must never surface raw Supabase exceptions; all failures are
/// mapped to the shared `Failure` type.
abstract class OrderRepository {
  /// Lists the current buyer's orders, newest first.
  Future<List<Order>> getOrders({int limit, int offset});

  /// Loads a single order with its items, status timeline, payment, and
  /// shipments/tracking. RLS guarantees only the owning buyer (or admin) can
  /// read it.
  Future<OrderDetail> getOrder(String orderId);

  /// Cancels [orderId] via the `cancel_order` RPC. The server enforces
  /// ownership and that the order is still cancellable; releases reserved
  /// inventory; and appends a `cancelled` status-history entry.
  Future<void> cancelOrder({required String orderId, String? reason});
}
