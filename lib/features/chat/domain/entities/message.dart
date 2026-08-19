import '../../../../core/utils/db_parsing.dart';

/// A chat message (`public.messages`). Read-only projection; sending goes
/// through the repository which sets `sender_profile_id` server-side.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderProfileId,
    this.messageType = 'text',
    this.text,
    this.attachmentPath,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderProfileId;
  final String messageType;
  final String? text;
  final String? attachmentPath;
  final DateTime? createdAt;

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderProfileId: map['sender_profile_id'] as String,
      messageType: map['message_type'] as String? ?? 'text',
      text: map['text'] as String?,
      attachmentPath: map['attachment_path'] as String?,
      createdAt: parseTimestamp(map['created_at']),
    );
  }
}
