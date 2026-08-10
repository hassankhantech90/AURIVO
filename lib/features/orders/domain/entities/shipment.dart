import '../../../../core/utils/db_parsing.dart';
import 'order_status.dart';

/// A shipment for an order (`public.shipments`).
///
/// Read-only from the buyer app — shipments are managed by sellers/admins.
class Shipment {
  const Shipment({
    required this.id,
    required this.orderId,
    this.courier,
    this.trackingNumber,
    this.trackingUrl,
    this.status = ShipmentStatus.pending,
    this.shippedAt,
    this.deliveredAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderId;
  final String? courier;
  final String? trackingNumber;
  final String? trackingUrl;
  final String status;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasTracking =>
      (trackingNumber != null && trackingNumber!.isNotEmpty) ||
      (trackingUrl != null && trackingUrl!.isNotEmpty);

  factory Shipment.fromMap(Map<String, dynamic> map) {
    return Shipment(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      courier: map['courier'] as String?,
      trackingNumber: map['tracking_number'] as String?,
      trackingUrl: map['tracking_url'] as String?,
      status: map['status'] as String? ?? ShipmentStatus.pending,
      shippedAt: parseTimestamp(map['shipped_at']),
      deliveredAt: parseTimestamp(map['delivered_at']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
