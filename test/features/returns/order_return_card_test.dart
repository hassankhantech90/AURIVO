import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/returns/data/supabase_return_repository.dart';
import 'package:aurivo/features/returns/domain/entities/return_request.dart';
import 'package:aurivo/features/returns/domain/repositories/return_repository.dart';
import 'package:aurivo/features/returns/presentation/order_return_card.dart';
import 'package:aurivo/features/returns/providers/return_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ReturnRequest _req(String status) => ReturnRequest(
  id: 'r1',
  orderId: 'o1',
  profileId: 'p1',
  reason: 'damaged',
  status: status,
  details: 'Stone loose',
);

class _FakeRepo implements ReturnRepository {
  _FakeRepo(this.current);
  ReturnRequest? current;
  final List<String> calls = [];

  @override
  Future<ReturnRequest?> latestForOrder(String orderId) async => current;

  ReturnRequest _set(String call, String status) {
    calls.add(call);
    return current = _req(status);
  }

  @override
  Future<ReturnRequest> request({
    required String orderId,
    required String reason,
    String? details,
  }) async => _set('request:$reason', ReturnRequest.requested);

  @override
  Future<ReturnRequest> cancel(String returnId) async =>
      _set('cancel', ReturnRequest.cancelled);

  @override
  Future<ReturnRequest> decide(
    String returnId, {
    required bool approve,
    String? note,
  }) async => _set(
    'decide:$approve:${note ?? ''}',
    approve ? ReturnRequest.approved : ReturnRequest.rejected,
  );

  @override
  Future<ReturnRequest> markReceived(String returnId) async =>
      _set('received', ReturnRequest.received);

  @override
  Future<ReturnRequest> markRefunded(String returnId, {String? note}) async =>
      _set('refunded', ReturnRequest.refunded);
}

Future<void> _pump(
  WidgetTester tester,
  _FakeRepo repo, {
  required ReturnViewer viewer,
  String orderStatus = 'delivered',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [returnRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderReturnCard(
              orderId: 'o1',
              orderStatus: orderStatus,
              viewer: viewer,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _StubDb extends SupabaseDatabaseService {
  _StubDb() : super(supabaseService: const SupabaseService());
  String? fn;
  Map<String, dynamic>? params;

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    fn = functionName;
    this.params = params;
    return {
      'id': 'r1',
      'order_id': 'o1',
      'profile_id': 'p1',
      'reason': 'damaged',
      'status': 'approved',
    };
  }
}

void main() {
  group('buyer', () {
    testWidgets('delivered order without a return offers Request a return', (
      tester,
    ) async {
      final repo = _FakeRepo(null);
      await _pump(tester, repo, viewer: ReturnViewer.buyer);

      await tester.tap(find.text('Request a return'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['request:damaged']);
      expect(find.text('Return requested'), findsOneWidget);
      expect(find.text('Withdraw return'), findsOneWidget);
    });

    testWidgets('nothing shown before delivery', (tester) async {
      await _pump(
        tester,
        _FakeRepo(null),
        viewer: ReturnViewer.buyer,
        orderStatus: 'shipped',
      );
      expect(find.text('Returns'), findsNothing);
    });

    testWidgets('buyer cannot approve their own return', (tester) async {
      await _pump(
        tester,
        _FakeRepo(_req(ReturnRequest.requested)),
        viewer: ReturnViewer.buyer,
      );
      expect(find.text('Approve return'), findsNothing);
    });
  });

  group('seller', () {
    testWidgets('approves, then marks received; cannot refund', (tester) async {
      final repo = _FakeRepo(_req(ReturnRequest.requested));
      await _pump(tester, repo, viewer: ReturnViewer.seller);

      await tester.tap(find.text('Approve return'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark item received'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['decide:true:', 'received']);
      expect(find.text('Record refund'), findsNothing);
    });

    testWidgets('declining requires a note', (tester) async {
      final repo = _FakeRepo(_req(ReturnRequest.requested));
      await _pump(tester, repo, viewer: ReturnViewer.seller);

      await tester.tap(find.text('Decline return'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Confirm');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Worn after delivery');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repo.calls, ['decide:false:Worn after delivery']);
    });
  });

  testWidgets('admin can record the refund once received', (tester) async {
    final repo = _FakeRepo(_req(ReturnRequest.received));
    await _pump(tester, repo, viewer: ReturnViewer.admin);

    await tester.tap(find.text('Record refund'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['refunded']);
    expect(find.text('Refunded'), findsOneWidget);
  });

  test('repository passes RPC params and parses the row', () async {
    final db = _StubDb();
    final repo = SupabaseReturnRepository(database: db);

    final r = await repo.decide('r1', approve: true, note: 'ok');

    expect(db.fn, 'decide_return');
    expect(db.params, {'p_return_id': 'r1', 'p_approve': true, 'p_note': 'ok'});
    expect(r.status, ReturnRequest.approved);
    expect(r.reasonLabel, 'Arrived damaged');
  });
}
