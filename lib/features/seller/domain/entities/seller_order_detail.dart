import '../../../../core/utils/db_parsing.dart';
import '../../../orders/domain/entities/order_item.dart';
import '../../../orders/domain/entities/shipment.dart';

/// A single order as seen by a seller fulfilling it: the fulfilment header (from
/// `seller_order_header()`), the seller's own line items, and the order's
/// shipment (if any). Cross-seller totals and the billing snapshot are never
/// exposed.
class SellerOrderDetail {
  const SellerOrderDetail({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.currency,
    required this.shippingAddress,
    required this.items,
    this.placedAt,
    this.shipment,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final String currency;

  /// Decoded `shipping_address_snapshot` (the address to ship to).
  final Map<String, dynamic> shippingAddress;
  final List<OrderItem> items;
  final DateTime? placedAt;
  final Shipment? shipment;

  /// Sum of this seller's own line totals in the order.
  double get sellerSubtotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  /// Builds the detail from the RPC header row plus the RLS-scoped items and
  /// optional shipment.
  factory SellerOrderDetail.fromParts({
    required Map<String, dynamic> header,
    required List<OrderItem> items,
    Shipment? shipment,
  }) {
    final snapshot = header['shipping_address_snapshot'];
    return SellerOrderDetail(
      orderId: header['order_id'] as String,
      orderNumber: header['order_number'] as String,
      status: header['status'] as String,
      currency: header['currency'] as String? ?? 'PKR',
      shippingAddress: snapshot is Map
          ? Map<String, dynamic>.from(snapshot)
          : const {},
      placedAt: parseTimestamp(header['placed_at']),
      items: items,
      shipment: shipment,
    );
  }
}
