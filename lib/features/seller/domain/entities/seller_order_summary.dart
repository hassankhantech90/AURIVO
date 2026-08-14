import '../../../../core/utils/db_parsing.dart';

/// A row from the `seller_orders()` RPC: one order that contains at least one of
/// the current seller's line items, with only fulfilment-relevant fields (never
/// other sellers' totals or the billing snapshot).
class SellerOrderSummary {
  const SellerOrderSummary({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.currency,
    required this.itemCount,
    required this.sellerSubtotal,
    this.placedAt,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final String currency;
  final int itemCount;

  /// Sum of this seller's own line totals in the order — not the order total.
  final double sellerSubtotal;
  final DateTime? placedAt;

  factory SellerOrderSummary.fromMap(Map<String, dynamic> map) {
    return SellerOrderSummary(
      orderId: map['order_id'] as String,
      orderNumber: map['order_number'] as String,
      status: map['status'] as String,
      currency: map['currency'] as String? ?? 'PKR',
      itemCount: parseInt(map['item_count']),
      sellerSubtotal: parseDouble(map['seller_subtotal']),
      placedAt: parseTimestamp(map['placed_at']),
    );
  }
}
