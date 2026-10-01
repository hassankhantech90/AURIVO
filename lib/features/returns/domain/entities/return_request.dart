import '../../../../core/utils/db_parsing.dart';

/// A buyer's return request for an order (`public.return_requests`).
/// Lifecycle: requested -> approved | rejected | cancelled; approved ->
/// received -> refunded. Every transition is a server RPC.
class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.orderId,
    required this.profileId,
    required this.reason,
    required this.status,
    this.details,
    this.resolutionNote,
    this.createdAt,
    this.decidedAt,
    this.receivedAt,
    this.refundedAt,
  });

  final String id;
  final String orderId;
  final String profileId;
  final String reason;
  final String status;
  final String? details;
  final String? resolutionNote;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final DateTime? receivedAt;
  final DateTime? refundedAt;

  static const requested = 'requested';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const received = 'received';
  static const refunded = 'refunded';
  static const cancelled = 'cancelled';

  /// Still in progress (blocks a new request for the same order).
  bool get isOpen =>
      status == requested || status == approved || status == received;

  /// Reason codes accepted by the server, with buyer-facing labels.
  static const reasons = <String, String>{
    'damaged': 'Arrived damaged',
    'not_as_described': 'Not as described',
    'wrong_item': 'Wrong item received',
    'size_fit': 'Size or fit issue',
    'changed_mind': 'Changed my mind',
    'other': 'Other',
  };

  String get reasonLabel => reasons[reason] ?? reason;

  String get statusLabel => switch (status) {
    requested => 'Return requested',
    approved => 'Return approved — send the item back',
    rejected => 'Return declined',
    received => 'Item received — refund pending',
    refunded => 'Refunded',
    cancelled => 'Return withdrawn',
    _ => status,
  };

  factory ReturnRequest.fromMap(Map<String, dynamic> map) {
    return ReturnRequest(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      profileId: map['profile_id'] as String,
      reason: map['reason'] as String,
      status: map['status'] as String,
      details: map['details'] as String?,
      resolutionNote: map['resolution_note'] as String?,
      createdAt: parseTimestamp(map['created_at']),
      decidedAt: parseTimestamp(map['decided_at']),
      receivedAt: parseTimestamp(map['received_at']),
      refundedAt: parseTimestamp(map['refunded_at']),
    );
  }
}
