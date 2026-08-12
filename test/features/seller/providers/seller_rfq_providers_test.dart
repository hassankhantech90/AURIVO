import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/seller/domain/entities/quote_draft.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_rfq_repository.dart';
import 'package:aurivo/features/seller/providers/seller_rfq_providers.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart'
    show SellerViewStatus;
import 'package:aurivo/features/wholesale/domain/entities/quote.dart';
import 'package:aurivo/features/wholesale/domain/entities/rfq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Rfq _rfq({String id = 'rfq-1'}) => Rfq.fromMap({
  'id': id,
  'buyer_profile_id': 'b1',
  'seller_profile_id': 'sp-1',
  'quantity': 10,
  'status': 'open',
});

Quote _quote({String id = 'q-1'}) => Quote.fromMap({
  'id': id,
  'rfq_id': 'rfq-1',
  'seller_profile_id': 'sp-1',
  'unit_price': 100,
  'total_price': 1000,
  'minimum_order_quantity': 10,
  'status': 'sent',
});

class _FakeRepo implements SellerRfqRepository {
  _FakeRepo({this.inbox = const [], this.myQuote, this.createError});
  List<Rfq> inbox;
  Quote? myQuote;
  final Object? createError;

  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<String?> mySellerProfileId() async => 'sp-1';

  @override
  Future<List<Rfq>> getInboxRfqs({int limit = 100, int offset = 0}) async =>
      inbox;

  @override
  Future<Rfq> getRfq(String rfqId) async => _rfq(id: rfqId);

  @override
  Future<Quote?> getMyQuoteForRfq(String rfqId) async => myQuote;

  @override
  Future<Quote> createQuote(String rfqId, QuoteDraft draft) async {
    createCalls++;
    if (createError != null) throw createError!;
    myQuote = _quote(id: 'new');
    return myQuote!;
  }

  @override
  Future<Quote> updateQuote(String quoteId, QuoteDraft draft) async {
    updateCalls++;
    myQuote = _quote(id: quoteId);
    return myQuote!;
  }

  @override
  Future<void> deleteQuote(String quoteId) async {
    deleteCalls++;
    myQuote = null;
  }
}

ProviderContainer _container(SellerRfqRepository repo) {
  final container = ProviderContainer(
    overrides: [sellerRfqRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('sellerRfqInboxProvider', () {
    test('load exposes matched RFQs', () async {
      final container = _container(_FakeRepo(inbox: [_rfq()]));
      await container.read(sellerRfqInboxProvider.notifier).load();
      final state = container.read(sellerRfqInboxProvider);
      expect(state.status, SellerViewStatus.success);
      expect(state.data!.single.id, 'rfq-1');
    });
  });

  group('sellerRfqDetailProvider', () {
    test('load exposes the rfq and my quote', () async {
      final container = _container(_FakeRepo(myQuote: _quote()));
      await container.read(sellerRfqDetailProvider('rfq-1').notifier).load();
      final state = container.read(sellerRfqDetailProvider('rfq-1'));
      expect(state.status, SellerViewStatus.success);
      expect(state.data!.rfq.id, 'rfq-1');
      expect(state.data!.hasQuote, isTrue);
    });

    test('submitQuote creates when no quote exists, then reloads', () async {
      final repo = _FakeRepo();
      final container = _container(repo);
      final notifier = container.read(
        sellerRfqDetailProvider('rfq-1').notifier,
      );
      await notifier.load();

      final error = await notifier.submitQuote(
        const QuoteDraft(
          unitPrice: 100,
          totalPrice: 1000,
          minimumOrderQuantity: 10,
        ),
      );

      expect(error, isNull);
      expect(repo.createCalls, 1);
      expect(repo.updateCalls, 0);
      expect(
        container.read(sellerRfqDetailProvider('rfq-1')).data!.hasQuote,
        isTrue,
      );
    });

    test('submitQuote updates when a quote already exists', () async {
      final repo = _FakeRepo(myQuote: _quote());
      final container = _container(repo);
      final notifier = container.read(
        sellerRfqDetailProvider('rfq-1').notifier,
      );
      await notifier.load();

      final error = await notifier.submitQuote(
        const QuoteDraft(
          unitPrice: 120,
          totalPrice: 1200,
          minimumOrderQuantity: 10,
        ),
      );

      expect(error, isNull);
      expect(repo.updateCalls, 1);
      expect(repo.createCalls, 0);
    });

    test('submitQuote returns the failure message', () async {
      final repo = _FakeRepo(
        createError: const Failure(
          message: 'You have already quoted this request.',
        ),
      );
      final container = _container(repo);
      final notifier = container.read(
        sellerRfqDetailProvider('rfq-1').notifier,
      );
      await notifier.load();

      final error = await notifier.submitQuote(
        const QuoteDraft(unitPrice: 1, totalPrice: 1),
      );
      expect(error, 'You have already quoted this request.');
    });

    test('deleteQuote removes the quote and reloads', () async {
      final repo = _FakeRepo(myQuote: _quote());
      final container = _container(repo);
      final notifier = container.read(
        sellerRfqDetailProvider('rfq-1').notifier,
      );
      await notifier.load();

      final error = await notifier.deleteQuote();
      expect(error, isNull);
      expect(repo.deleteCalls, 1);
      expect(
        container.read(sellerRfqDetailProvider('rfq-1')).data!.hasQuote,
        isFalse,
      );
    });
  });
}
