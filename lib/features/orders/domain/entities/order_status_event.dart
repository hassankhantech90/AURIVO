import '../../../../core/utils/db_parsing.dart';

/// A single entry in an order's status timeline (`public.order_status_history`).
/// Read-only from the buyer app — appended server-side by the checkout RPC,
/// sellers, or admins.
class OrderStatusEvent {
  const OrderStatusEvent({
    required this.id,
    required this.orderId,
    required this.status,
    this.changedBy,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String orderId;
  final String status;
  final String? changedBy;
  final String? notes;
  final DateTime? createdAt;

  factory OrderStatusEvent.fromMap(Map<String, dynamic> map) {
    return OrderStatusEvent(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      status: map['status'] as String,
      changedBy: map['changed_by'] as String?,
      notes: map['notes'] as String?,
      createdAt: parseTimestamp(map['created_at']),
    );
  }
}
