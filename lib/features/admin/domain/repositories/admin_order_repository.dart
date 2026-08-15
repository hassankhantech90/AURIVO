import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/entities/order_detail.dart';

/// Contract for admin order oversight. Reads all orders and their sub-records
/// via the admin RLS arm (`has_role('admin')`); non-admins are denied
/// server-side. Status changes go through the audited `order_status_history`
/// path (a trigger syncs `orders.status`); cancellation uses the
/// `admin_cancel_order` RPC so reserved inventory is released. Failures map to
/// the shared `Failure` type.
abstract class AdminOrderRepository {
  /// All orders (optionally filtered by [status]), newest first.
  Future<List<Order>> listOrders({String? status});

  /// Full order detail: header, items, status timeline, payment, shipments and
  /// tracking events.
  Future<OrderDetail> getOrder(String orderId);

  /// Appends a status to the order's history (audited); the sync trigger
  /// updates `orders.status`. Not for cancellation — use [cancelOrder].
  Future<void> advanceStatus({
    required String orderId,
    required String status,
    String? notes,
  });

  /// Sets the order's payment record status.
  Future<void> setPaymentStatus({
    required String orderId,
    required String status,
  });

  /// Cancels an order via `admin_cancel_order` (releases reserved inventory,
  /// appends history; only from pending/confirmed).
  Future<void> cancelOrder({required String orderId, String? reason});
}
