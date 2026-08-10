import 'order.dart';
import 'order_item.dart';
import 'order_status_event.dart';
import 'payment.dart';
import 'shipment.dart';
import 'tracking_event.dart';

/// Aggregate read shape for the order-detail screen: the order header plus its
/// items, status timeline, payment, and shipments/tracking. Every part is a
/// read-only buyer projection assembled from RLS-scoped SELECTs.
class OrderDetail {
  const OrderDetail({
    required this.order,
    this.items = const [],
    this.statusHistory = const [],
    this.payment,
    this.shipments = const [],
    this.trackingEvents = const [],
  });

  final Order order;
  final List<OrderItem> items;
  final List<OrderStatusEvent> statusHistory;
  final Payment? payment;
  final List<Shipment> shipments;
  final List<TrackingEvent> trackingEvents;

  /// Total number of units across all lines.
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Number of distinct line items.
  int get lineCount => items.length;

  /// Tracking events belonging to [shipmentId], newest first is the caller's
  /// responsibility (they arrive ordered by `event_time DESC` from the repo).
  List<TrackingEvent> eventsForShipment(String shipmentId) =>
      trackingEvents.where((e) => e.shipmentId == shipmentId).toList();
}
