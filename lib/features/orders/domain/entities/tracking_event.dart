import '../../../../core/utils/db_parsing.dart';

/// A tracking event on a shipment (`public.tracking_events`).
/// Read-only from the buyer app.
class TrackingEvent {
  const TrackingEvent({
    required this.id,
    required this.shipmentId,
    required this.status,
    this.location,
    this.description,
    this.eventTime,
    this.createdAt,
  });

  final String id;
  final String shipmentId;
  final String status;
  final String? location;
  final String? description;
  final DateTime? eventTime;
  final DateTime? createdAt;

  factory TrackingEvent.fromMap(Map<String, dynamic> map) {
    return TrackingEvent(
      id: map['id'] as String,
      shipmentId: map['shipment_id'] as String,
      status: map['status'] as String,
      location: map['location'] as String?,
      description: map['description'] as String?,
      eventTime: parseTimestamp(map['event_time']),
      createdAt: parseTimestamp(map['created_at']),
    );
  }
}
