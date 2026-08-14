import '../../../orders/domain/entities/shipment.dart';
import '../entities/seller_order_detail.dart';
import '../entities/seller_order_summary.dart';

/// Contract for a seller fulfilling the orders that include their products.
///
/// Order headers come from the `seller_orders()` / `seller_order_header()`
/// SECURITY DEFINER RPCs (sellers have no direct RLS SELECT on `orders`). Line
/// items and shipments are read through the existing seller-scoped RLS. All
/// writes are ownership-enforced server-side — no order/seller id from the UI is
/// ever trusted. Implementations map failures to the shared `Failure` type.
abstract class SellerOrderRepository {
  /// Orders containing at least one of the seller's items, newest first.
  Future<List<SellerOrderSummary>> getOrders();

  /// A single order's fulfilment view (header + the seller's items + shipment).
  Future<SellerOrderDetail> getOrder(String orderId);

  /// Appends a fulfilment status (`packed` or `shipped`) to the order's status
  /// history. RLS permits this only for orders containing the seller's items;
  /// a trigger syncs `orders.status`.
  Future<void> advanceStatus({required String orderId, required String status});

  /// Creates or updates the order's shipment (courier, tracking, status). RLS
  /// scopes the write to orders containing the seller's items.
  Future<Shipment> saveShipment({
    required String orderId,
    required String status,
    String? courier,
    String? trackingNumber,
    String? trackingUrl,
  });
}
