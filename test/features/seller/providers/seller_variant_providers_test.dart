import 'package:aurivo/features/seller/domain/entities/seller_variant.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_variant_repository.dart';
import 'package:aurivo/features/seller/providers/seller_variant_providers.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart'
    show SellerViewStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerVariant _variant({String id = 'v1'}) => SellerVariant(
  id: id,
  productId: 'prod-1',
  sku: 'SKU-$id',
  price: 1000,
  stockQuantity: 5,
);

class _FakeRepo implements SellerVariantRepository {
  _FakeRepo({this.variants = const []});
  List<SellerVariant> variants;
  int createCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<SellerVariant>> getVariants(String productId) async => variants;

  @override
  Future<SellerVariant> createVariant(String productId, VariantDraft d) async {
    createCalls++;
    final created = _variant(id: 'new');
    variants = [...variants, created];
    return created;
  }

  @override
  Future<SellerVariant> updateVariant(String id, VariantDraft d) async =>
      _variant(id: id);

  @override
  Future<void> softDelete(String id) async {
    deleteCalls++;
    variants = variants.where((v) => v.id != id).toList();
  }
}

ProviderContainer _container(SellerVariantRepository repo) {
  final container = ProviderContainer(
    overrides: [sellerVariantRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load exposes variants', () async {
    final container = _container(_FakeRepo(variants: [_variant()]));
    await container.read(productVariantsProvider('prod-1').notifier).load();
    final state = container.read(productVariantsProvider('prod-1'));
    expect(state.status, SellerViewStatus.success);
    expect(state.data!.single.id, 'v1');
  });

  test('create then reload', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final error = await container
        .read(productVariantsProvider('prod-1').notifier)
        .create(const VariantDraft(sku: 'S', price: 10));
    expect(error, isNull);
    expect(repo.createCalls, 1);
    expect(container.read(productVariantsProvider('prod-1')).data, isNotEmpty);
  });

  test('remove then reload', () async {
    final repo = _FakeRepo(variants: [_variant()]);
    final container = _container(repo);
    await container.read(productVariantsProvider('prod-1').notifier).load();
    final error = await container
        .read(productVariantsProvider('prod-1').notifier)
        .remove('v1');
    expect(error, isNull);
    expect(repo.deleteCalls, 1);
    expect(container.read(productVariantsProvider('prod-1')).data, isEmpty);
  });
}
