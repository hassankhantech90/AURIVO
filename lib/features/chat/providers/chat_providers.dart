import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_chat_repository.dart';
import '../domain/entities/conversation.dart';
import '../domain/entities/message.dart';
import '../domain/repositories/chat_repository.dart';

/// Repository binding (lazy service — stays test-safe without an initialized
/// Supabase client).
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return SupabaseChatRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

enum ChatStatus { initial, loading, success, failure }

class ConversationsState {
  const ConversationsState({
    this.status = ChatStatus.initial,
    this.items = const [],
    this.message,
  });

  final ChatStatus status;
  final List<ConversationSummary> items;
  final String? message;

  int get unreadCount => items.where((c) => c.hasUnread).length;
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
      return ConversationsNotifier(ref.watch(chatRepositoryProvider));
    });

/// Unread conversation count for the home chat badge.
final unreadChatCountProvider = Provider<int>((ref) {
  return ref.watch(conversationsProvider).unreadCount;
});

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  ConversationsNotifier(this._repository) : super(const ConversationsState());

  final ChatRepository _repository;

  Future<void> load() async {
    state = ConversationsState(
      status: ChatStatus.loading,
      items: state.items,
    );
    try {
      state = ConversationsState(
        status: ChatStatus.success,
        items: await _repository.getConversations(),
      );
    } catch (error) {
      state = ConversationsState(
        status: ChatStatus.failure,
        items: state.items,
        message: error.toString(),
      );
    }
  }
}

/// Live messages for a conversation (realtime).
final chatMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
      return ref.watch(chatRepositoryProvider).streamMessages(conversationId);
    });
