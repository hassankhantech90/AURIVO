import 'package:aurivo/features/categories/domain/entities/category.dart';
import 'package:aurivo/features/products/domain/entities/brand.dart';
import 'package:aurivo/features/seller/domain/entities/product_draft.dart';
import 'package:aurivo/features/seller/domain/entities/seller_product.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_product_repository.dart';
import 'package:aurivo/features/seller/providers/seller_product_providers.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart'
    show SellerViewStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerProduct _product({String id = 'prod-1', String status = 'draft'}) =>
    SellerProduct(
      id: id,
      sellerId: 'sp-1',
      title: 'Ring',
      slug: 'ring',
      jewelleryType: 'ring',
      basePrice: 1000,
      status: status,
    );

class _FakeRepo implements SellerProductRepository {
  _FakeRepo({this.products = const [], this.createError});
  List<SellerProduct> products;
  final Object? createError;

  int createCalls = 0;
  int setPublishedCalls = 0;
  int softDeleteCalls = 0;

  @override
  Future<String?> mySellerProfileId() async => 'sp-1';

  @override
  Future<List<SellerProduct>> getMyProducts({
    int limit = 100,
    int offset = 0,
  }) async => products;

  @override
  Future<SellerProductDetail> getProduct(String id) async =>
      SellerProductDetail(product: _product(id: id));

  @override
  Future<SellerProduct> createProduct(ProductDraft draft) async {
    createCalls++;
    if (createError != null) throw createError!;
    final created = _product(id: 'new');
    products = [created, ...products];
    return created;
  }

  @override
  Future<SellerProduct> updateProduct(String id, ProductDraft draft) async =>
      _product(id: id);

  @override
  Future<SellerProduct> setPublished(String id, bool published) async {
    setPublishedCalls++;
    return _product(id: id, status: published ? 'approved' : 'draft');
  }

  @override
  Future<void> softDelete(String id) async {
    softDeleteCalls++;
    products = products.where((p) => p.id != id).toList();
  }

  @override
  Future<List<Brand>> getBrands() async => const [];

  @override
  Future<List<Category>> getCategories() async => const [];
}

ProviderContainer _container(SellerProductRepository repo) {
  final container = ProviderContainer(
    overrides: [sellerProductRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load exposes the seller products', () async {
    final container = _container(_FakeRepo(products: [_product()]));
    await container.read(myProductsProvider.notifier).load();
    final state = container.read(myProductsProvider);
    expect(state.status, SellerViewStatus.success);
    expect(state.data!.single.id, 'prod-1');
  });

  test('create calls createProduct then reloads', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final error = await container
        .read(myProductsProvider.notifier)
        .create(
          const ProductDraft(
            title: 'Ring',
            slug: 'ring',
            jewelleryType: 'ring',
            basePrice: 1000,
          ),
        );
    expect(error, isNull);
    expect(repo.createCalls, 1);
    expect(container.read(myProductsProvider).data!.isNotEmpty, isTrue);
  });

  test('create returns the failure message', () async {
    final repo = _FakeRepo(createError: const _Err('slug in use'));
    final container = _container(repo);
    final error = await container
        .read(myProductsProvider.notifier)
        .create(
          const ProductDraft(
            title: 'Ring',
            slug: 'ring',
            jewelleryType: 'ring',
            basePrice: 1000,
          ),
        );
    expect(error, 'slug in use');
  });

  test('setPublished and softDelete reload the list', () async {
    final repo = _FakeRepo(products: [_product()]);
    final container = _container(repo);
    await container.read(myProductsProvider.notifier).load();

    expect(
      await container
          .read(myProductsProvider.notifier)
          .setPublished('prod-1', true),
      isNull,
    );
    expect(repo.setPublishedCalls, 1);

    expect(
      await container.read(myProductsProvider.notifier).softDelete('prod-1'),
      isNull,
    );
    expect(repo.softDeleteCalls, 1);
    expect(container.read(myProductsProvider).data, isEmpty);
  });
}

class _Err implements Exception {
  const _Err(this.message);
  final String message;
  @override
  String toString() => message;
}
