import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/wholesale/domain/entities/rfq.dart';
import 'package:aurivo/features/wholesale/domain/entities/rfq_detail.dart';
import 'package:aurivo/features/wholesale/domain/repositories/rfq_repository.dart';
import 'package:aurivo/features/wholesale/providers/rfq_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Rfq _rfq({String id = 'rfq-1', String status = 'open'}) => Rfq.fromMap({
  'id': id,
  'buyer_profile_id': 'p1',
  'quantity': 10,
  'status': status,
});

class _FakeRfqRepository implements RFQRepository {
  _FakeRfqRepository({this.createError});
  final Object? createError;
  String status = 'open';
  int createCalls = 0;
  int cancelCalls = 0;
  int getRfqCalls = 0;

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
    if (createError != null) throw createError!;
    return _rfq(id: 'new');
  }

  @override
  Future<List<Rfq>> getMyRfqs({int limit = 50, int offset = 0}) async => [
    _rfq(),
  ];

  @override
  Future<RfqDetail> getRfq(String rfqId) async {
    getRfqCalls++;
    return RfqDetail(
      rfq: _rfq(id: rfqId, status: status),
    );
  }

  @override
  Future<Rfq> cancelRfq(String rfqId) async {
    cancelCalls++;
    status = 'cancelled';
    return _rfq(id: rfqId, status: status);
  }
}

ProviderContainer _container(RFQRepository repo) {
  final container = ProviderContainer(
    overrides: [rfqRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('myRfqsProvider', () {
    test('load exposes the buyer RFQs', () async {
      final container = _container(_FakeRfqRepository());
      await container.read(myRfqsProvider.notifier).load();
      final state = container.read(myRfqsProvider);
      expect(state.status, RfqViewStatus.success);
      expect(state.data!.single.id, 'rfq-1');
    });

    test('create success calls createRfq then reloads', () async {
      final repo = _FakeRfqRepository();
      final container = _container(repo);
      final error = await container
          .read(myRfqsProvider.notifier)
          .create(quantity: 10, productId: 'p');
      expect(error, isNull);
      expect(repo.createCalls, 1);
      expect(container.read(myRfqsProvider).status, RfqViewStatus.success);
    });

    test('create failure returns the message', () async {
      final repo = _FakeRfqRepository(
        createError: const Failure(message: 'Please enter a valid quantity.'),
      );
      final container = _container(repo);
      final error = await container
          .read(myRfqsProvider.notifier)
          .create(quantity: 0);
      expect(error, 'Please enter a valid quantity.');
    });
  });

  group('rfqDetailProvider', () {
    test('load exposes the detail', () async {
      final container = _container(_FakeRfqRepository());
      await container.read(rfqDetailProvider('rfq-1').notifier).load();
      final state = container.read(rfqDetailProvider('rfq-1'));
      expect(state.status, RfqViewStatus.success);
      expect(state.data!.rfq.id, 'rfq-1');
    });

    test('cancel returns true and reloads the cancelled rfq', () async {
      final repo = _FakeRfqRepository();
      final container = _container(repo);
      final notifier = container.read(rfqDetailProvider('rfq-1').notifier);
      await notifier.load();

      final ok = await notifier.cancel();

      expect(ok, isTrue);
      expect(repo.cancelCalls, 1);
      expect(repo.getRfqCalls, 2); // load + reload
      expect(
        container.read(rfqDetailProvider('rfq-1')).data!.rfq.status,
        'cancelled',
      );
    });
  });
}
