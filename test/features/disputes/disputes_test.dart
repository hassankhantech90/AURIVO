import 'dart:typed_data';

import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/supabase/supabase_storage_service.dart';
import 'package:aurivo/features/disputes/data/supabase_dispute_repository.dart';
import 'package:aurivo/features/disputes/domain/entities/dispute.dart';
import 'package:aurivo/features/disputes/domain/repositories/dispute_repository.dart';
import 'package:aurivo/features/disputes/presentation/order_dispute_entry.dart';
import 'package:aurivo/features/disputes/providers/dispute_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Dispute _d({String status = Dispute.open, String id = 'd1'}) => Dispute(
  id: id,
  orderId: 'o1',
  openedBy: 'me',
  reason: 'damaged',
  status: status,
);

class _FakeRepo implements DisputeRepository {
  _FakeRepo(this.latest);
  Dispute? latest;
  final List<String> calls = [];
  List<DisputeMessage> messages = [];

  @override
  Future<String?> currentProfileId() async => 'me';

  @override
  Future<Dispute?> latestForOrder(String orderId) async => latest;

  @override
  Future<Dispute> getDispute(String disputeId) async => latest ?? _d();

  @override
  Future<List<Dispute>> listByStatus(String status) async => [_d(status: status)];

  @override
  Future<List<DisputeMessage>> getMessages(String disputeId) async => messages;

  @override
  Future<Dispute> openDispute({
    required String orderId,
    required String reason,
    required String description,
  }) async {
    calls.add('open:$reason:$description');
    return latest = _d();
  }

  @override
  Future<Dispute> withdraw(String disputeId) async {
    calls.add('withdraw');
    return latest = _d(status: Dispute.withdrawn);
  }

  @override
  Future<Dispute> resolve(
    String disputeId, {
    required String resolution,
    double? refundAmount,
    required String note,
  }) async {
    calls.add('resolve:$resolution:$refundAmount:$note');
    return latest = _d(status: Dispute.resolved);
  }

  @override
  Future<void> sendMessage({
    required String disputeId,
    required String body,
    bool internal = false,
    List<String> attachments = const [],
  }) async => calls.add('send:$body:$internal:${attachments.join(',')}');

  @override
  Future<String> uploadEvidence({
    required String disputeId,
    required Uint8List bytes,
    required String extension,
  }) async {
    calls.add('upload:$extension');
    return '$disputeId/x.$extension';
  }

  @override
  Future<String> evidenceUrl(String path) async => 'https://signed/$path';
}

Widget _wrap(_FakeRepo repo, {String status = 'delivered'}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: OrderDisputeEntry(orderId: 'o1', orderStatus: status),
        ),
      ),
      GoRoute(
        path: '/disputes/:id',
        builder: (_, s) => Text('THREAD ${s.pathParameters['id']}'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [disputeRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _StubDb extends SupabaseDatabaseService {
  _StubDb() : super(supabaseService: const SupabaseService());
  final List<(String, Map<String, dynamic>)> rpcs = [];

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    rpcs.add((functionName, params));
    return {
      'id': 'd1',
      'order_id': 'o1',
      'opened_by': 'me',
      'reason': 'damaged',
      'status': 'resolved',
      'resolution': 'refund_partial',
      'refund_amount': 5000,
    };
  }
}

void main() {
  testWidgets('opening a dispute calls the RPC and goes to the thread', (
    tester,
  ) async {
    final repo = _FakeRepo(null);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open a dispute'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Clasp broke on day one');
    await tester.pump();
    await tester.tap(find.text('Open dispute'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['open:not_received:Clasp broke on day one']);
    expect(find.text('THREAD d1'), findsOneWidget);
  });

  testWidgets('an open dispute links to its thread instead', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(_d())));
    await tester.pumpAndSettle();
    expect(find.text('View dispute (open)'), findsOneWidget);
    expect(find.text('Open a dispute'), findsNothing);
  });

  testWidgets('not offered before the order ships', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(null), status: 'pending'));
    await tester.pumpAndSettle();
    expect(find.text('Open a dispute'), findsNothing);
  });

  test('thread send uploads evidence first, then posts with paths', () async {
    final repo = _FakeRepo(_d());
    final container = ProviderContainer(
      overrides: [disputeRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(disputeThreadProvider('d1'), (_, _) {});
    addTearDown(sub.close);
    await container.read(disputeThreadProvider('d1').notifier).load();

    final error = await container
        .read(disputeThreadProvider('d1').notifier)
        .send(
          'See photo',
          images: [(Uint8List.fromList([1, 2, 3]), 'png')],
        );

    expect(error, isNull);
    expect(repo.calls, ['upload:png', 'send:See photo:false:d1/x.png']);
    expect(container.read(disputeThreadProvider('d1')).value!.openedByMe, isTrue);
  });

  test('repository resolve passes params and parses the dispute', () async {
    final db = _StubDb();
    final repo = SupabaseDisputeRepository(
      database: db,
      storage: const SupabaseStorageService(supabaseService: SupabaseService()),
    );

    final d = await repo.resolve(
      'd1',
      resolution: 'refund_partial',
      refundAmount: 5000,
      note: 'Size difference',
    );

    expect(db.rpcs.single.$1, 'resolve_dispute');
    expect(db.rpcs.single.$2, {
      'p_dispute_id': 'd1',
      'p_resolution': 'refund_partial',
      'p_refund_amount': 5000,
      'p_note': 'Size difference',
    });
    expect(d.refundAmount, 5000);
    expect(d.statusLabel, 'Resolved — Partial refund');
  });
}
