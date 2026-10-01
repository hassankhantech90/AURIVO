import '../../../../core/utils/db_parsing.dart';

/// A dispute on an order (`public.disputes`): opened by the buyer or one of
/// the order's sellers, resolved by an admin with a refund decision.
class Dispute {
  const Dispute({
    required this.id,
    required this.orderId,
    required this.openedBy,
    required this.reason,
    required this.status,
    this.resolution,
    this.refundAmount,
    this.resolutionNote,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String orderId;
  final String openedBy;
  final String reason;
  final String status;
  final String? resolution;
  final double? refundAmount;
  final String? resolutionNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  static const open = 'open';
  static const resolved = 'resolved';
  static const withdrawn = 'withdrawn';

  bool get isOpen => status == open;

  static const reasons = <String, String>{
    'not_received': 'Order not received',
    'damaged': 'Item damaged',
    'not_as_described': 'Not as described',
    'counterfeit': 'Suspected counterfeit',
    'return_issue': 'Problem with a return',
    'payment_issue': 'Payment problem',
    'other': 'Other',
  };

  static const resolutions = <String, String>{
    'refund_full': 'Full refund',
    'refund_partial': 'Partial refund',
    'no_refund': 'No refund',
  };

  String get reasonLabel => reasons[reason] ?? reason;

  String get statusLabel => switch (status) {
    open => 'Open',
    resolved => 'Resolved — ${resolutions[resolution] ?? resolution ?? ''}',
    withdrawn => 'Withdrawn',
    _ => status,
  };

  factory Dispute.fromMap(Map<String, dynamic> map) => Dispute(
    id: map['id'] as String,
    orderId: map['order_id'] as String,
    openedBy: map['opened_by'] as String,
    reason: map['reason'] as String,
    status: map['status'] as String,
    resolution: map['resolution'] as String?,
    refundAmount: parseDoubleOrNull(map['refund_amount']),
    resolutionNote: map['resolution_note'] as String?,
    createdAt: parseTimestamp(map['created_at']),
    resolvedAt: parseTimestamp(map['resolved_at']),
  );
}

/// One message in a dispute thread. [attachments] are storage paths in the
/// private `dispute-evidence` bucket; [isInternal] notes are admin-only.
class DisputeMessage {
  const DisputeMessage({
    required this.id,
    required this.disputeId,
    required this.authorProfileId,
    required this.body,
    this.isInternal = false,
    this.attachments = const [],
    this.createdAt,
  });

  final String id;
  final String disputeId;
  final String authorProfileId;
  final String body;
  final bool isInternal;
  final List<String> attachments;
  final DateTime? createdAt;

  factory DisputeMessage.fromMap(Map<String, dynamic> map) => DisputeMessage(
    id: map['id'] as String,
    disputeId: map['dispute_id'] as String,
    authorProfileId: map['author_profile_id'] as String,
    body: map['body'] as String,
    isInternal: map['is_internal'] as bool? ?? false,
    attachments: [
      for (final a in (map['attachments'] as List? ?? const []))
        if (a is String) a,
    ],
    createdAt: parseTimestamp(map['created_at']),
  );
}
