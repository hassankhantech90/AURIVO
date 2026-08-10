/// Canonical status value sets for the order domain.
///
/// These mirror the `CHECK` constraints on the live database (see the Phase 3
/// audit). They are intentionally plain string constants — the backend stores
/// statuses as `text`, not Postgres enums — plus small display/label helpers so
/// the UI never hard-codes raw values.
class OrderStatus {
  const OrderStatus._();

  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const processing = 'processing';
  static const packed = 'packed';
  static const shipped = 'shipped';
  static const delivered = 'delivered';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const returned = 'returned';
  static const refunded = 'refunded';

  /// All valid order statuses, in lifecycle order.
  static const all = <String>[
    pending,
    confirmed,
    processing,
    packed,
    shipped,
    delivered,
    completed,
    cancelled,
    returned,
    refunded,
  ];

  /// Statuses from which a buyer may cancel via the `cancel_order` RPC.
  /// Mirrors the server-side guard exactly; the UI uses it only to decide
  /// whether to *offer* cancellation — the RPC remains authoritative.
  static bool isCancellable(String status) =>
      status == pending || status == confirmed;

  /// Whether the order has reached a terminal state.
  static bool isTerminal(String status) =>
      status == completed ||
      status == cancelled ||
      status == returned ||
      status == refunded;

  /// Human-friendly label for [status].
  static String label(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case confirmed:
        return 'Confirmed';
      case processing:
        return 'Processing';
      case packed:
        return 'Packed';
      case shipped:
        return 'Shipped';
      case delivered:
        return 'Delivered';
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      case returned:
        return 'Returned';
      case refunded:
        return 'Refunded';
      default:
        return status;
    }
  }
}

/// Status value set for `payments.status` / `orders.payment_status`.
class PaymentStatus {
  const PaymentStatus._();

  static const pending = 'pending';
  static const authorized = 'authorized';
  static const paid = 'paid';
  static const failed = 'failed';
  static const partiallyRefunded = 'partially_refunded';
  static const refunded = 'refunded';

  static String label(String status) {
    switch (status) {
      case pending:
        return 'Payment pending';
      case authorized:
        return 'Authorized';
      case paid:
        return 'Paid';
      case failed:
        return 'Payment failed';
      case partiallyRefunded:
        return 'Partially refunded';
      case refunded:
        return 'Refunded';
      default:
        return status;
    }
  }
}

/// Status value set for `shipments.status`.
class ShipmentStatus {
  const ShipmentStatus._();

  static const pending = 'pending';
  static const readyToShip = 'ready_to_ship';
  static const shipped = 'shipped';
  static const inTransit = 'in_transit';
  static const outForDelivery = 'out_for_delivery';
  static const delivered = 'delivered';
  static const failed = 'failed';
  static const returned = 'returned';
  static const cancelled = 'cancelled';

  static String label(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case readyToShip:
        return 'Ready to ship';
      case shipped:
        return 'Shipped';
      case inTransit:
        return 'In transit';
      case outForDelivery:
        return 'Out for delivery';
      case delivered:
        return 'Delivered';
      case failed:
        return 'Delivery failed';
      case returned:
        return 'Returned';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}

/// Payment methods supported by the MVP. COD only — no gateway integration.
class PaymentMethod {
  const PaymentMethod._();

  static const cashOnDelivery = 'cash_on_delivery';

  static String label(String method) {
    switch (method) {
      case cashOnDelivery:
        return 'Cash on delivery';
      default:
        return method;
    }
  }
}
