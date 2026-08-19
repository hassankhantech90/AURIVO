import '../entities/conversation.dart';
import '../entities/message.dart';

/// Contract for buyer<->seller chat. Reads/sends are governed by the existing
/// participant RLS; conversation creation and read-state go through the
/// `start_conversation` / `mark_conversation_read` SECURITY DEFINER RPCs. No
/// profile id is taken from the UI. Failures map to the shared `Failure` type.
abstract class ChatRepository {
  /// The caller's conversations (newest activity first) with unread flags.
  Future<List<ConversationSummary>> getConversations();

  /// Messages in a conversation, oldest first.
  Future<List<Message>> getMessages(String conversationId);

  /// Live message stream for a conversation (realtime), oldest first.
  Stream<List<Message>> streamMessages(String conversationId);

  /// Sends a text message; the sender is resolved server-side. Marks the
  /// conversation read for the sender.
  Future<Message> sendMessage({
    required String conversationId,
    required String text,
  });

  /// Starts (or reuses) a conversation with a seller store, optionally scoped to
  /// an order or RFQ. Returns the conversation id. The counterpart is derived
  /// server-side from context.
  Future<String> startConversation({
    required String sellerProfileId,
    String? orderId,
    String? rfqId,
  });

  /// Marks the conversation read for the current user.
  Future<void> markRead(String conversationId);
}
