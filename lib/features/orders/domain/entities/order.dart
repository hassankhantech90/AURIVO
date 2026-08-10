import '../../../../core/utils/db_parsing.dart';
import 'order_status.dart';

/// An order header (`public.orders`).
///
/// All monetary fields are maintained authoritatively by the database via the
/// `checkout_cart` RPC — the client never computes or sends them. The address
/// snapshots are immutable JSON copies frozen at checkout time.
class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.profileId,
    this.addressId,
    this.status = OrderStatus.pending,
    this.paymentStatus = PaymentStatus.pending,
    this.currency = 'PKR',
    this.subtotal = 0,
    this.shippingFee = 0,
    this.discountTotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
    this.shippingAddressSnapshot = const {},
    this.billingAddressSnapshot = const {},
    this.notes,
    this.placedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderNumber;
  final String profileId;
  final String? addressId;
  final String status;
  final String paymentStatus;
  final String currency;
  final double subtotal;
  final double shippingFee;
  final double discountTotal;
  final double taxTotal;
  final double grandTotal;
  final Map<String, dynamic> shippingAddressSnapshot;
  final Map<String, dynamic> billingAddressSnapshot;
  final String? notes;
  final DateTime? placedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Whether the buyer may attempt cancellation (server-side guard is final).
  bool get isCancellable => OrderStatus.isCancellable(status);

  bool get isTerminal => OrderStatus.isTerminal(status);

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as String,
      orderNumber: map['order_number'] as String,
      profileId: map['profile_id'] as String,
      addressId: map['address_id'] as String?,
      status: map['status'] as String? ?? OrderStatus.pending,
      paymentStatus: map['payment_status'] as String? ?? PaymentStatus.pending,
      currency: map['currency'] as String? ?? 'PKR',
      subtotal: parseDouble(map['subtotal']),
      shippingFee: parseDouble(map['shipping_fee']),
      discountTotal: parseDouble(map['discount_total']),
      taxTotal: parseDouble(map['tax_total']),
      grandTotal: parseDouble(map['grand_total']),
      shippingAddressSnapshot: _asJsonObject(map['shipping_address_snapshot']),
      billingAddressSnapshot: _asJsonObject(map['billing_address_snapshot']),
      notes: map['notes'] as String?,
      placedAt: parseTimestamp(map['placed_at']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  static Map<String, dynamic> _asJsonObject(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
