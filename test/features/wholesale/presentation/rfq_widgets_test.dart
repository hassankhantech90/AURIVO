import 'package:aurivo/features/wholesale/domain/entities/quote.dart';
import 'package:aurivo/features/wholesale/domain/entities/rfq.dart';
import 'package:aurivo/features/wholesale/domain/entities/rfq_detail.dart';
import 'package:aurivo/features/wholesale/domain/repositories/rfq_repository.dart';
import 'package:aurivo/features/wholesale/presentation/rfq_detail_page.dart';
import 'package:aurivo/features/wholesale/presentation/wholesale_page.dart';
import 'package:aurivo/features/wholesale/presentation/widgets/quote_tile.dart';
import 'package:aurivo/features/wholesale/presentation/widgets/rfq_form_sheet.dart';
import 'package:aurivo/features/wholesale/providers/rfq_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Rfq _rfq({String id = 'rfq-1', int quantity = 10, String status = 'open'}) =>
    Rfq.fromMap({
      'id': id,
      'buyer_profile_id': 'p1',
      'quantity': quantity,
      'status': status,
    });

Quote _quote({String id = 'q1'}) => Quote.fromMap({
  'id': id,
  'rfq_id': 'rfq-1',
  'seller_profile_id': 's1',
  'unit_price': 120,
  'total_price': 1200,
  'currency': 'PKR',
  'minimum_order_quantity': 10,
  'status': 'sent',
});

class _FakeRfqRepository implements RFQRepository {
  _FakeRfqRepository({this.detail});
  final RfqDetail? detail;

  int createCalls = 0;
  int? lastQuantity;
  String? lastProductId;

  @override
  Future<List<Rfq>> getMyRfqs({int limit = 50, int offset = 0}) async =>
      const [];

  @override
  Future<RfqDetail> getRfq(String rfqId) async =>
      detail ?? RfqDetail(rfq: _rfq(id: rfqId));

  @override
  Future<Rfq> createRfq({
    required int quantity,
    String? productId,
    String? productVariantId,
    String? sellerProfileId,
    String? businessProfileId,
    double? targetPrice,
    String currency = 'PKR',
    String? message,
  }) async {
    createCalls++;
    lastQuantity = quantity;
    lastProductId = productId;
    return _rfq(id: 'new');
  }

  @override
  Future<Rfq> cancelRfq(String rfqId) async =>
      _rfq(id: rfqId, status: 'cancelled');
}

Widget _wrap(Widget child, RFQRepository repo) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => child)],
  );
  return ProviderScope(
    overrides: [rfqRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  // Session is unauthenticated in tests (no Supabase config) unless overridden.
  testWidgets('WholesalePage prompts guests to sign in', (tester) async {
    await tester.pumpWidget(_wrap(const WholesalePage(), _FakeRfqRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Request wholesale quotes'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('RfqDetailPage shows the request and its quotes', (tester) async {
    final repo = _FakeRfqRepository(
      detail: RfqDetail(
        rfq: _rfq(quantity: 42),
        quotes: [
          _quote(),
          _quote(id: 'q2'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(const RfqDetailPage(rfqId: 'rfq-1'), repo));
    await tester.pumpAndSettle();

    expect(find.text('Quantity 42'), findsOneWidget);
    expect(find.byType(QuoteTile), findsNWidgets(2));
    // Cancellable (open) → cancel button visible.
    expect(find.text('Cancel request'), findsOneWidget);
  });

  testWidgets(
    'RfqDetailPage shows empty-quotes state and hides cancel when terminal',
    (tester) async {
      final repo = _FakeRfqRepository(
        detail: RfqDetail(rfq: _rfq(status: 'cancelled')),
      );
      await tester.pumpWidget(_wrap(const RfqDetailPage(rfqId: 'rfq-1'), repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('No quotes yet'), findsOneWidget);
      expect(find.text('Cancel request'), findsNothing);
    },
  );

  testWidgets('RfqFormSheet submits quantity + context and creates an RFQ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRfqRepository();
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => RfqFormSheet.show(
                  context,
                  productId: 'prod-1',
                  sellerProfileId: 's1',
                  contextLabel: 'Gold Ring',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Gold Ring'), findsOneWidget); // context shown

    await tester.enterText(find.byType(TextField).first, '250');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(repo.lastQuantity, 250);
    expect(repo.lastProductId, 'prod-1');
    // Sheet dismissed on success.
    expect(find.text('Send request'), findsNothing);
  });

  testWidgets('RfqFormSheet rejects an empty/invalid quantity', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRfqRepository();
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => RfqFormSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        repo,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 0);
    expect(find.textContaining('quantity of at least 1'), findsOneWidget);
  });
}
