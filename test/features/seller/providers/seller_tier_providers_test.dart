import 'package:aurivo/features/products/domain/entities/price_tier.dart';
import 'package:aurivo/features/seller/domain/entities/price_tier_draft.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_tier_repository.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart'
    show SellerViewStatus;
import 'package:aurivo/features/seller/providers/seller_tier_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PriceTier _tier({String id = 't1', int minQuantity = 10}) => PriceTier(
  id: id,
  productId: 'prod-1',
  minQuantity: minQuantity,
  unitPrice: 82000,
);

class _FakeRepo implements SellerTierRepository {
  _FakeRepo({this.tiers = const []});
  List<PriceTier> tiers;
  int createCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<PriceTier>> getTiers(String productId) async => tiers;

  @override
  Future<PriceTier> createTier(String productId, PriceTierDraft d) async {
    createCalls++;
    final created = _tier(id: 'new', minQuantity: d.minQuantity);
    tiers = [...tiers, created];
    return created;
  }

  @override
  Future<PriceTier> updateTier(String id, PriceTierDraft d) async =>
      _tier(id: id, minQuantity: d.minQuantity);

  @override
  Future<void> deleteTier(String id) async {
    deleteCalls++;
    tiers = tiers.where((t) => t.id != id).toList();
  }
}

ProviderContainer _container(SellerTierRepository repo) {
  final container = ProviderContainer(
    overrides: [sellerTierRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load exposes tiers', () async {
    final container = _container(_FakeRepo(tiers: [_tier()]));
    await container.read(productTiersProvider('prod-1').notifier).load();
    final state = container.read(productTiersProvider('prod-1'));
    expect(state.status, SellerViewStatus.success);
    expect(state.data!.single.id, 't1');
  });

  test('create then reload', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final error = await container
        .read(productTiersProvider('prod-1').notifier)
        .create(const PriceTierDraft(minQuantity: 20, unitPrice: 100));
    expect(error, isNull);
    expect(repo.createCalls, 1);
    expect(container.read(productTiersProvider('prod-1')).data, isNotEmpty);
  });

  test('remove then reload', () async {
    final repo = _FakeRepo(tiers: [_tier()]);
    final container = _container(repo);
    await container.read(productTiersProvider('prod-1').notifier).load();
    final error = await container
        .read(productTiersProvider('prod-1').notifier)
        .remove('t1');
    expect(error, isNull);
    expect(repo.deleteCalls, 1);
    expect(container.read(productTiersProvider('prod-1')).data, isEmpty);
  });
}
