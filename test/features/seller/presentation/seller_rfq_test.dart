import 'package:aurivo/features/seller/domain/entities/quote_draft.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_rfq_repository.dart';
import 'package:aurivo/features/seller/presentation/seller_rfq_inbox_page.dart';
import 'package:aurivo/features/seller/presentation/widgets/quote_form_sheet.dart';
import 'package:aurivo/features/seller/providers/seller_product_providers.dart'
    show mySellerProfileIdProvider;
import 'package:aurivo/features/seller/providers/seller_rfq_providers.dart';
import 'package:aurivo/features/wholesale/domain/entities/quote.dart';
import 'package:aurivo/features/wholesale/domain/entities/rfq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Rfq _rfq({String id = 'rfq-1', int qty = 10}) => Rfq.fromMap({
  'id': id,
  'buyer_profile_id': 'b1',
  'seller_profile_id': 'sp-1',
  'quantity': qty,
  'status': 'open',
});

class _FakeRepo implements SellerRfqRepository {
  _FakeRepo({this.inbox = const []});
  final List<Rfq> inbox;
  int createCalls = 0;
  QuoteDraft? lastDraft;

  @override
  Future<String?> mySellerProfileId() async => 'sp-1';

  @override
  Future<List<Rfq>> getInboxRfqs({int limit = 100, int offset = 0}) async =>
      inbox;

  @override
  Future<Rfq> getRfq(String rfqId) async => _rfq(id: rfqId);

  @override
  Future<Quote?> getMyQuoteForRfq(String rfqId) async => null;

  @override
  Future<Quote> createQuote(String rfqId, QuoteDraft draft) async {
    createCalls++;
    lastDraft = draft;
    return Quote.fromMap({
      'id': 'q-new',
      'rfq_id': rfqId,
      'seller_profile_id': 'sp-1',
      'unit_price': draft.unitPrice,
      'total_price': draft.totalPrice,
      'minimum_order_quantity': draft.minimumOrderQuantity,
      'status': 'sent',
    });
  }

  @override
  Future<Quote> updateQuote(String quoteId, QuoteDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteQuote(String quoteId) async {}
}

Widget _wrapInbox({
  required String? sellerId,
  required SellerRfqRepository repo,
}) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const SellerRfqInboxPage())],
  );
  return ProviderScope(
    overrides: [
      mySellerProfileIdProvider.overrideWith((ref) async => sellerId),
      sellerRfqRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _wrapForm(SellerRfqRepository repo) {
  return ProviderScope(
    overrides: [sellerRfqRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => QuoteFormSheet.show(context, rfqId: 'rfq-1'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('inbox lists matched RFQs for a seller', (tester) async {
    await tester.pumpWidget(
      _wrapInbox(
        sellerId: 'sp-1',
        repo: _FakeRepo(inbox: [_rfq(qty: 42)]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Qty 42'), findsOneWidget);
  });

  testWidgets('inbox shows a prompt for non-sellers', (tester) async {
    await tester.pumpWidget(_wrapInbox(sellerId: null, repo: _FakeRepo()));
    await tester.pumpAndSettle();
    expect(find.text('No seller store yet'), findsOneWidget);
  });

  testWidgets('quote form rejects total < unit price x MOQ', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrapForm(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '100'); // unit price
    await tester.enterText(find.byType(TextField).at(1), '10'); // moq
    await tester.enterText(
      find.byType(TextField).at(2),
      '50',
    ); // total (< 1000)
    await tester.tap(find.text('Send quote'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 0);
    expect(find.textContaining('at least unit price'), findsOneWidget);
  });

  testWidgets('quote form submits a valid quote', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrapForm(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.enterText(find.byType(TextField).at(2), '1000');
    await tester.tap(find.text('Send quote'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(repo.lastDraft!.totalPrice, 1000);
    expect(find.text('Send quote'), findsNothing); // sheet dismissed
  });
}
