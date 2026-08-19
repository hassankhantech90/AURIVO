import 'dart:async';

import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/chat/domain/entities/conversation.dart';
import 'package:aurivo/features/chat/domain/entities/message.dart';
import 'package:aurivo/features/chat/domain/repositories/chat_repository.dart';
import 'package:aurivo/features/chat/providers/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ConversationSummary _summary(
  String id, {
  DateTime? lastMessageAt,
  DateTime? readAt,
}) => ConversationSummary(
  conversation: Conversation(id: id, lastMessageAt: lastMessageAt),
  myLastReadAt: readAt,
);

Message _message(String id) => Message(
  id: id,
  conversationId: 'c1',
  senderProfileId: 'me',
  messageType: 'text',
  text: 'hi',
);

class _FakeRepo implements ChatRepository {
  _FakeRepo(this._conversations);
  final List<ConversationSummary> _conversations;
  Object? loadError;
  final StreamController<List<Message>> messageStream =
      StreamController<List<Message>>.broadcast();

  @override
  Future<List<ConversationSummary>> getConversations() async {
    if (loadError != null) throw loadError!;
    return _conversations;
  }

  @override
  Future<List<Message>> getMessages(String conversationId) async => const [];

  @override
  Stream<List<Message>> streamMessages(String conversationId) =>
      messageStream.stream;

  @override
  Future<Message> sendMessage({
    required String conversationId,
    required String text,
  }) async => _message('sent');

  @override
  Future<String> startConversation({
    required String sellerProfileId,
    String? orderId,
    String? rfqId,
  }) async => 'conv-new';

  @override
  Future<void> markRead(String conversationId) async {}
}

ProviderContainer _container(ChatRepository repo) {
  final container = ProviderContainer(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final base = DateTime.parse('2026-08-20T10:00:00Z');

  test('load exposes conversations and success status', () async {
    final repo = _FakeRepo([_summary('c1', lastMessageAt: base)]);
    final container = _container(repo);
    await container.read(conversationsProvider.notifier).load();
    final state = container.read(conversationsProvider);
    expect(state.status, ChatStatus.success);
    expect(state.items.single.conversation.id, 'c1');
  });

  test('unread count reflects unread conversations', () async {
    final repo = _FakeRepo([
      _summary('c1', lastMessageAt: base), // never read -> unread
      _summary(
        'c2',
        lastMessageAt: base,
        readAt: base.add(const Duration(hours: 1)),
      ), // read after -> read
      _summary('c3'), // no messages -> not unread
    ]);
    final container = _container(repo);
    await container.read(conversationsProvider.notifier).load();
    expect(container.read(conversationsProvider).unreadCount, 1);
    expect(container.read(unreadChatCountProvider), 1);
  });

  test('load failure surfaces failure status and message', () async {
    final repo = _FakeRepo([])..loadError = const Failure(message: 'nope');
    final container = _container(repo);
    await container.read(conversationsProvider.notifier).load();
    final state = container.read(conversationsProvider);
    expect(state.status, ChatStatus.failure);
    expect(state.message, contains('nope'));
  });

  test('chatMessagesProvider streams messages from the repo', () async {
    final repo = _FakeRepo([]);
    final container = _container(repo);
    // Subscribe so the family provider stays alive.
    final sub = container.listen(chatMessagesProvider('c1'), (_, _) {});
    addTearDown(sub.close);
    repo.messageStream.add([_message('m1')]);
    await Future<void>.delayed(Duration.zero);
    final value = container.read(chatMessagesProvider('c1'));
    expect(value.value?.single.id, 'm1');
    await repo.messageStream.close();
  });
}
