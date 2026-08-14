import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/domain/repositories/admin_repository.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart';
import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/seller/domain/entities/seller_product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerProfile _seller(String id) => SellerProfile(
  id: id,
  profileId: 'p-$id',
  storeName: 'Store $id',
  slug: 'store-$id',
  verificationStatus: 'pending',
);

SellerProduct _product(String id) => SellerProduct.fromMap({
  'id': id,
  'seller_id': 'sp1',
  'title': 'Ring $id',
  'slug': 'ring-$id',
  'jewellery_type': 'ring',
  'currency': 'PKR',
  'base_price': 1000,
  'status': 'pending',
});

class _FakeRepo implements AdminRepository {
  _FakeRepo({this.admin = true});
  final bool admin;

  final List<String> verifications = [];
  final List<String> productStatuses = [];

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<List<SellerProfile>> getPendingSellers() async =>
      [_seller('a'), _seller('b')];

  @override
  Future<void> setSellerVerification({
    required String sellerId,
    required String status,
  }) async {
    verifications.add('$sellerId:$status');
  }

  @override
  Future<List<SellerProduct>> getPendingProducts() async =>
      [_product('x'), _product('y')];

  @override
  Future<void> setProductStatus({
    required String productId,
    required String status,
  }) async {
    productStatuses.add('$productId:$status');
  }
}

ProviderContainer _container(AdminRepository repo) {
  final container = ProviderContainer(
    overrides: [adminRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('isAdminProvider reflects the repository', () async {
    final container = _container(_FakeRepo(admin: true));
    expect(await container.read(isAdminProvider.future), isTrue);
  });

  test('pendingSellers load then approve removes from the queue', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(pendingSellersProvider.notifier);
    await notifier.load();
    expect(container.read(pendingSellersProvider).data.map((s) => s.id),
        ['a', 'b']);

    final err = await notifier.setVerification('a', 'verified');
    expect(err, isNull);
    expect(repo.verifications, ['a:verified']);
    expect(container.read(pendingSellersProvider).data.map((s) => s.id), ['b']);
  });

  test('pendingProducts load then reject removes from the queue', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(pendingProductsProvider.notifier);
    await notifier.load();
    expect(container.read(pendingProductsProvider).data, hasLength(2));

    final err = await notifier.setStatus('x', 'rejected');
    expect(err, isNull);
    expect(repo.productStatuses, ['x:rejected']);
    expect(container.read(pendingProductsProvider).data.map((p) => p.id), ['y']);
  });

  test('setVerification surfaces an error message on failure', () async {
    final repo = _ThrowingRepo();
    final container = _container(repo);
    await container.read(pendingSellersProvider.notifier).load();
    final err = await container
        .read(pendingSellersProvider.notifier)
        .setVerification('a', 'verified');
    expect(err, contains('denied'));
  });
}

class _ThrowingRepo extends _FakeRepo {
  @override
  Future<void> setSellerVerification({
    required String sellerId,
    required String status,
  }) async {
    throw const Failure(message: 'denied');
  }
}
