import 'dart:async';

import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/chat/data/repositories/supabase_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> convRow({
  String id = 'c1',
  String? lastMessageAt = '2026-08-20T10:00:00Z',
  String? deletedAt,
}) => {
  'id': id,
  'subject': 'Zarina Jewels',
  'conversation_type': 'buyer_seller',
  'order_id': null,
  'rfq_id': null,
  'last_message_at': lastMessageAt,
  'created_at': '2026-08-19T09:00:00Z',
  'deleted_at': deletedAt,
};

Map<String, dynamic> participantRow({
  String conversationId = 'c1',
  String? lastReadAt,
}) => {
  'conversation_id': conversationId,
  'profile_id': 'me',
  'last_read_at': lastReadAt,
};

Map<String, dynamic> messageRow({
  String id = 'm1',
  String? deletedAt,
  String text = 'Hello',
}) => {
  'id': id,
  'conversation_id': 'c1',
  'sender_profile_id': 'me',
  'message_type': 'text',
  'text': text,
  'attachment_path': null,
  'created_at': '2026-08-20T10:00:00Z',
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  // Keyed by table name so getConversations can return two different lists.
  Map<String, List<Map<String, dynamic>>> rowsByTable = const {};
  Object? insertError;
  Object? rpcError;
  String profileId = 'me';

  final List<Map<String, dynamic>> inserted = [];
  final List<String> rpcCalls = [];
  final List<Map<String, dynamic>> rpcParams = [];
  final List<Map<String, Object?>> listFilters = [];
  StreamController<List<Map<String, dynamic>>>? streamController;
  Map<String, Object?>? streamArgs;

  @override
  Future<List<Map<String, dynamic>>> list({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
    Map<String, List<Object>> whereIn = const {},
    String? ilikeColumn,
    String? ilikeQuery,
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    listFilters.add(filters);
    return rowsByTable[table] ?? const [];
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add(values);
    return {...messageRow(), ...values};
  }

  @override
  Stream<List<Map<String, dynamic>>> stream({
    required String table,
    required List<String> primaryKey,
    String? filterColumn,
    Object? filterValue,
    String? orderBy,
    bool ascending = true,
  }) {
    streamArgs = {
      'table': table,
      'filterColumn': filterColumn,
      'filterValue': filterValue,
      'orderBy': orderBy,
    };
    streamController = StreamController<List<Map<String, dynamic>>>();
    return streamController!.stream;
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    rpcCalls.add(functionName);
    rpcParams.add(params);
    if (rpcError != null) throw rpcError!;
    switch (functionName) {
      case 'current_profile_id':
        return profileId;
      case 'start_conversation':
        return 'conv-new';
      case 'mark_conversation_read':
        return null;
      default:
        return null;
    }
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseChatRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseChatRepository(database: db);
  });

  group('getConversations', () {
    test('builds summaries, drops soft-deleted, derives unread', () async {
      db.rowsByTable = {
        'conversations': [
          convRow(id: 'c1'),
          convRow(id: 'gone', deletedAt: '2026-08-01T00:00:00Z'),
        ],
        'conversation_participants': [
          participantRow(
            conversationId: 'c1',
            lastReadAt: '2026-08-20T09:00:00Z',
          ),
        ],
      };
      final summaries = await repo.getConversations();
      expect(summaries.map((s) => s.conversation.id), ['c1']);
      // last_message_at (10:00) is after last_read_at (09:00) -> unread.
      expect(summaries.single.hasUnread, isTrue);
      // Owner resolved server-side, participant rows filtered by profile.
      expect(db.rpcCalls, contains('current_profile_id'));
      expect(db.listFilters.last['profile_id'], 'me');
    });

    test('read after last message -> not unread', () async {
      db.rowsByTable = {
        'conversations': [convRow(id: 'c1')],
        'conversation_participants': [
          participantRow(
            conversationId: 'c1',
            lastReadAt: '2026-08-20T11:00:00Z',
          ),
        ],
      };
      final summaries = await repo.getConversations();
      expect(summaries.single.hasUnread, isFalse);
    });
  });

  group('getMessages', () {
    test('drops soft-deleted and maps rows', () async {
      db.rowsByTable = {
        'messages': [
          messageRow(id: 'm1'),
          messageRow(id: 'm2', deletedAt: '2026-08-20T10:05:00Z'),
        ],
      };
      final messages = await repo.getMessages('c1');
      expect(messages.map((m) => m.id), ['m1']);
      expect(db.listFilters.single['conversation_id'], 'c1');
    });
  });

  group('sendMessage', () {
    test('resolves sender server-side, trims, and marks read', () async {
      final message = await repo.sendMessage(
        conversationId: 'c1',
        text: '  hi there  ',
      );
      final row = db.inserted.single;
      expect(row['sender_profile_id'], 'me');
      expect(row['message_type'], 'text');
      expect(row['text'], 'hi there');
      expect(row['conversation_id'], 'c1');
      expect(message.text, 'hi there');
      // markRead follows the insert.
      expect(db.rpcCalls, contains('mark_conversation_read'));
    });

    test('maps a permission error to a friendly Failure', () async {
      db.insertError = const ex.DatabaseException('denied', code: '42501');
      await expectLater(
        repo.sendMessage(conversationId: 'c1', text: 'hi'),
        throwsA(
          predicate(
            (e) =>
                e is Failure &&
                e.message.contains('not able to access this conversation'),
          ),
        ),
      );
    });
  });

  group('startConversation', () {
    test('passes only the seller id for a general chat', () async {
      final id = await repo.startConversation(sellerProfileId: 'seller-1');
      expect(id, 'conv-new');
      final params = db.rpcParams[db.rpcCalls.indexOf('start_conversation')];
      expect(params['p_seller_profile_id'], 'seller-1');
      expect(params.containsKey('p_order_id'), isFalse);
      expect(params.containsKey('p_rfq_id'), isFalse);
    });

    test('includes order context when provided', () async {
      await repo.startConversation(
        sellerProfileId: 'seller-1',
        orderId: 'order-9',
      );
      final params = db.rpcParams[db.rpcCalls.indexOf('start_conversation')];
      expect(params['p_order_id'], 'order-9');
      expect(params.containsKey('p_rfq_id'), isFalse);
    });

    test('includes rfq context when provided', () async {
      await repo.startConversation(
        sellerProfileId: 'seller-1',
        rfqId: 'rfq-7',
      );
      final params = db.rpcParams[db.rpcCalls.indexOf('start_conversation')];
      expect(params['p_rfq_id'], 'rfq-7');
      expect(params.containsKey('p_order_id'), isFalse);
    });

    test('maps an RPC failure to a Failure', () async {
      db.rpcError = const ex.DatabaseException('nope', code: '42501');
      await expectLater(
        repo.startConversation(sellerProfileId: 'seller-1'),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('markRead', () {
    test('calls the mark_conversation_read RPC with the conversation id',
        () async {
      await repo.markRead('c1');
      final params = db.rpcParams[db.rpcCalls.indexOf('mark_conversation_read')];
      expect(params['p_conversation_id'], 'c1');
    });
  });

  group('streamMessages', () {
    test('applies conversation filter/order and maps + drops deleted',
        () async {
      final stream = repo.streamMessages('c1');
      final future = stream.first;
      db.streamController!.add([
        messageRow(id: 'm1'),
        messageRow(id: 'm2', deletedAt: '2026-08-20T10:05:00Z'),
      ]);
      final messages = await future;
      expect(messages.map((m) => m.id), ['m1']);
      expect(db.streamArgs!['filterColumn'], 'conversation_id');
      expect(db.streamArgs!['filterValue'], 'c1');
      expect(db.streamArgs!['orderBy'], 'created_at');
      await db.streamController!.close();
    });
  });
}
