import '../../../../core/utils/db_parsing.dart';

/// A conversation (`public.conversations`). [subject] is the seller store name
/// captured at creation (the counterpart's profile is not readable under RLS,
/// which keeps the buyer's identity private to the seller).
class Conversation {
  const Conversation({
    required this.id,
    this.subject,
    this.conversationType = 'buyer_seller',
    this.orderId,
    this.rfqId,
    this.lastMessageAt,
    this.createdAt,
  });

  final String id;
  final String? subject;
  final String conversationType;
  final String? orderId;
  final String? rfqId;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      subject: map['subject'] as String?,
      conversationType: map['conversation_type'] as String? ?? 'buyer_seller',
      orderId: map['order_id'] as String?,
      rfqId: map['rfq_id'] as String?,
      lastMessageAt: parseTimestamp(map['last_message_at']),
      createdAt: parseTimestamp(map['created_at']),
    );
  }
}

/// A conversation row for the list, with the caller's read cursor and a derived
/// unread flag.
class ConversationSummary {
  const ConversationSummary({
    required this.conversation,
    this.myLastReadAt,
  });

  final Conversation conversation;
  final DateTime? myLastReadAt;

  /// Unread when there is a newer message than the caller last read. (Own
  /// messages are marked read on send, so this stays accurate for the sender.)
  bool get hasUnread {
    final last = conversation.lastMessageAt;
    if (last == null) return false;
    return myLastReadAt == null || last.isAfter(myLastReadAt!);
  }
}
