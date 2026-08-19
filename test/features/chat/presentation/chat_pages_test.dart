import 'dart:async';

import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/chat/domain/entities/conversation.dart';
import 'package:aurivo/features/chat/domain/entities/message.dart';
import 'package:aurivo/features/chat/domain/repositories/chat_repository.dart';
import 'package:aurivo/features/chat/presentation/chat_thread_page.dart';
import 'package:aurivo/features/chat/presentation/messages_page.dart';
import 'package:aurivo/features/chat/providers/chat_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthedSession extends SessionNotifier {
  _AuthedSession()
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      ) {
    state = const SessionState(status: SessionStatus.authenticated);
  }
}

ConversationSummary _summary(String id, {String subject = 'Zarina Jewels'}) =>
    ConversationSummary(
      conversation: Conversation(
        id: id,
        subject: subject,
        conversationType: 'buyer_seller',
        lastMessageAt: DateTime.parse('2026-08-20T10:00:00Z'),
      ),
    );

Message _message(String id, {required String sender, String text = 'Hi'}) =>
    Message(
      id: id,
      conversationId: 'c1',
      senderProfileId: sender,
      messageType: 'text',
      text: text,
      createdAt: DateTime.parse('2026-08-20T10:00:00Z'),
    );

class _FakeRepo implements ChatRepository {
  _FakeRepo({this.conversations = const []});
  final List<ConversationSummary> conversations;
  final StreamController<List<Message>> messages =
      StreamController<List<Message>>.broadcast();
  final List<String> sent = [];

  @override
  Future<List<ConversationSummary>> getConversations() async => conversations;

  @override
  Future<List<Message>> getMessages(String conversationId) async => const [];

  @override
  Stream<List<Message>> streamMessages(String conversationId) =>
      messages.stream;

  @override
  Future<Message> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    sent.add(text);
    return _message('new', sender: 'me', text: text);
  }

  @override
  Future<String> startConversation({
    required String sellerProfileId,
    String? orderId,
    String? rfqId,
  }) async => 'conv-new';

  @override
  Future<void> markRead(String conversationId) async {}
}

Widget _wrap(List<Override> overrides, Widget page) =>
    ProviderScope(overrides: overrides, child: MaterialApp(home: page));

void main() {
  testWidgets('guests are prompted to sign in on messages', (tester) async {
    await tester.pumpWidget(
      _wrap(
        [chatRepositoryProvider.overrideWithValue(_FakeRepo())],
        const MessagesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to view messages'), findsOneWidget);
  });

  testWidgets('authed user sees their conversations', (tester) async {
    await tester.pumpWidget(
      _wrap(
        [
          chatRepositoryProvider.overrideWithValue(
            _FakeRepo(conversations: [_summary('c1')]),
          ),
          sessionProvider.overrideWith((ref) => _AuthedSession()),
        ],
        const MessagesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Zarina Jewels'), findsOneWidget);
  });

  testWidgets('thread renders streamed messages and sends', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      _wrap(
        [
          chatRepositoryProvider.overrideWithValue(repo),
          myProfileIdProvider.overrideWith((ref) async => 'me'),
        ],
        const ChatThreadPage(conversationId: 'c1'),
      ),
    );
    await tester.pump(); // let the stream provider subscribe
    repo.messages.add([
      _message('m1', sender: 'seller', text: 'Hello there'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Hello there'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'On my way');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(repo.sent, contains('On my way'));

    await repo.messages.close();
  });
}
