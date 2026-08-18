import '../../../../core/utils/db_parsing.dart';

/// A support ticket (`public.support_tickets`). Owned by [profileId]; an admin
/// agent may be [assignedTo] it. Category/priority/status mirror the DB checks.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.profileId,
    this.orderId,
    required this.subject,
    required this.description,
    this.category = 'general',
    this.priority = 'normal',
    this.status = 'open',
    this.assignedTo,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String profileId;
  final String? orderId;
  final String subject;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String? assignedTo;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOpen => status == 'open' || status == 'pending';

  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    return SupportTicket(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      orderId: map['order_id'] as String?,
      subject: map['subject'] as String,
      description: map['description'] as String,
      category: map['category'] as String? ?? 'general',
      priority: map['priority'] as String? ?? 'normal',
      status: map['status'] as String? ?? 'open',
      assignedTo: map['assigned_to'] as String?,
      closedAt: parseTimestamp(map['closed_at']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}

/// Allowed enum values (mirror the `support_tickets` CHECK constraints).
class SupportTicketMeta {
  const SupportTicketMeta._();

  static const categories = [
    'general',
    'order',
    'payment',
    'shipping',
    'return',
    'product',
    'seller',
    'technical',
  ];
  static const priorities = ['low', 'normal', 'high', 'urgent'];
  static const statuses = ['open', 'pending', 'resolved', 'closed'];

  static String label(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
