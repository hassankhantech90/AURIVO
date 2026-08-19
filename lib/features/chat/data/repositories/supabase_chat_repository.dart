import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../chat_failure_mapper.dart';

/// Supabase-backed [ChatRepository]. Reads/sends rely on the participant RLS;
/// conversation creation and read-state go through the SECURITY DEFINER RPCs.
class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const _conversations = 'conversations';
  static const _participants = 'conversation_participants';
  static const _messages = 'messages';

  @override
  Future<List<ConversationSummary>> getConversations() async {
    try {
      final me = await _requireProfileId();
      final convRows = await _database.list(
        table: _conversations,
        orderBy: 'last_message_at',
        ascending: false,
        limit: 100,
      );
      // My participant rows carry my per-conversation read cursor.
      final myParticipantRows = await _database.list(
        table: _participants,
        filters: {'profile_id': me},
      );
      final readByConversation = {
        for (final p in myParticipantRows)
          p['conversation_id'] as String: p['last_read_at'],
      };

      return convRows
          .where((r) => r['deleted_at'] == null)
          .map(
            (r) => ConversationSummary(
              conversation: Conversation.fromMap(r),
              myLastReadAt: _parse(readByConversation[r['id']]),
            ),
          )
          .toList();
    } catch (error) {
      throw ChatFailureMapper.map(error);
    }
  }

  @override
  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final rows = await _database.list(
        table: _messages,
        filters: {'conversation_id': conversationId},
        orderBy: 'created_at',
      );
      return rows
          .where((r) => r['deleted_at'] == null)
          .map(Message.fromMap)
          .toList();
    } catch (error) {
      throw ChatFailureMapper.map(error);
    }
  }

  @override
  Stream<List<Message>> streamMessages(String conversationId) {
    return _database
        .stream(
          table: _messages,
          primaryKey: const ['id'],
          filterColumn: 'conversation_id',
          filterValue: conversationId,
          orderBy: 'created_at',
        )
        .map(
          (rows) => rows
              .where((r) => r['deleted_at'] == null)
              .map(Message.fromMap)
              .toList(),
        );
  }

  @override
  Future<Message> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    try {
      final row = await _database.insert(
        table: _messages,
        values: {
          'conversation_id': conversationId,
          'sender_profile_id': await _requireProfileId(),
          'message_type': 'text',
          'text': text.trim(),
        },
      );
      // Own messages shouldn't leave the thread showing unread.
      await markRead(conversationId);
      return Message.fromMap(row);
    } catch (error) {
      throw ChatFailureMapper.map(error);
    }
  }

  @override
  Future<String> startConversation({
    required String sellerProfileId,
    String? orderId,
    String? rfqId,
  }) async {
    try {
      final params = <String, dynamic>{'p_seller_profile_id': sellerProfileId};
      if (orderId != null) params['p_order_id'] = orderId;
      if (rfqId != null) params['p_rfq_id'] = rfqId;
      final result = await _database.rpc(
        functionName: 'start_conversation',
        params: params,
      );
      if (result is String && result.isNotEmpty) return result;
      throw const Failure(message: 'Could not open the conversation.');
    } catch (error) {
      throw ChatFailureMapper.map(error);
    }
  }

  @override
  Future<void> markRead(String conversationId) async {
    try {
      await _database.rpc(
        functionName: 'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (error) {
      throw ChatFailureMapper.map(error);
    }
  }

  DateTime? _parse(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  Future<String> _requireProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) return result;
    throw const Failure(message: 'Please sign in to chat.');
  }
}
