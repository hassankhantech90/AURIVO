import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/products/domain/entities/attribute.dart';
import 'package:aurivo/features/products/domain/entities/brand.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_detail.dart';
import 'package:aurivo/features/products/domain/entities/product_image.dart';
import 'package:aurivo/features/products/domain/entities/product_sort.dart';
import 'package:aurivo/features/products/domain/entities/product_variant.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/providers/catalog_state.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(String id) => Product(
  id: id,
  sellerId: 'seller-1',
  title: 'Ring $id',
  slug: 'ring-$id',
  jewelleryType: 'ring',
  basePrice: 1000,
);

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({this.products = const [], this.error});

  final List<Product> products;
  final Object? error;

  @override
  Future<List<Product>> getProducts({
    int limit = 20,
    int offset = 0,
    String? brandId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    ProductSort sort = ProductSort.newest,
  }) async {
    if (error != null) throw error!;
    return products;
  }

  @override
  Future<Product?> getProductById(String id) async {
    if (error != null) throw error!;
    return products.isEmpty ? null : products.first;
  }

  @override
  Future<List<Product>> getProductsByIds(List<String> ids) async {
    if (error != null) throw error!;
    return products.where((p) => ids.contains(p.id)).toList();
  }

  @override
  Future<ProductDetail?> getProductDetail(String id) async {
    if (error != null) throw error!;
    return null;
  }

  @override
  Future<List<Product>> getProductsByCategory(
    String categoryId, {
    int limit = 20,
    int offset = 0,
  }) async => products;

  @override
  Future<List<Product>> getProductsByBrand(
    String brandId, {
    int limit = 20,
    int offset = 0,
  }) async => products;

  @override
  Future<List<ProductImage>> getProductImages(String productId) async =>
      const [];

  @override
  Future<List<ProductVariant>> getProductVariants(String productId) async =>
      const [];

  @override
  Future<List<Brand>> getBrands() async {
    if (error != null) throw error!;
    return const [];
  }

  @override
  Future<Brand?> getBrandById(String id) async => null;

  @override
  Future<List<Attribute>> getAttributes({bool filterableOnly = false}) async =>
      const [];

  @override
  Future<List<AttributeValue>> getAttributeValues(String attributeId) async =>
      const [];
}

/// Returns a distinct detail per product id, and can mark ids as missing
/// (null detail -> "no longer available") or failing (throws). Records how many
/// times each id's detail was fetched so retry isolation can be asserted.
class _IdAwareRepo implements ProductRepository {
  _IdAwareRepo({Set<String>? missing, Set<String>? failing})
    : missing = missing ?? <String>{},
      failing = failing ?? <String>{};

  final Set<String> missing;
  final Set<String> failing;
  final Map<String, int> detailCalls = {};

  @override
  Future<ProductDetail?> getProductDetail(String id) async {
    detailCalls[id] = (detailCalls[id] ?? 0) + 1;
    if (failing.contains(id)) throw const Failure(message: 'boom');
    if (missing.contains(id)) return null;
    return ProductDetail(product: _product(id));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(ProductRepository repo) {
  final container = ProviderContainer(
    overrides: [productRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('productListProvider', () {
    test('starts in initial state', () {
      final container = _container(_FakeProductRepository());
      expect(
        container.read(productListProvider).status,
        CatalogViewStatus.initial,
      );
    });

    test('load sets success with data', () async {
      final container = _container(
        _FakeProductRepository(products: [_product('p1'), _product('p2')]),
      );

      await container.read(productListProvider.notifier).load();

      final state = container.read(productListProvider);
      expect(state.status, CatalogViewStatus.success);
      expect(state.data, hasLength(2));
    });

    test('load maps repository Failure to failure state', () async {
      final container = _container(
        _FakeProductRepository(error: const Failure(message: 'RLS blocked')),
      );

      await container.read(productListProvider.notifier).load();

      final state = container.read(productListProvider);
      expect(state.status, CatalogViewStatus.failure);
      expect(state.message, 'RLS blocked');
    });
  });

  group('productDetailProvider', () {
    // autoDispose family instances need a live listener to survive across the
    // separate container.read calls a test makes.
    void pin(ProviderContainer c, String id) {
      c.listen(productDetailProvider(id), (_, _) {});
    }

    test('success when detail is found', () async {
      final container = _container(_IdAwareRepo());
      pin(container, 'p1');

      await container.read(productDetailProvider('p1').notifier).load();

      final state = container.read(productDetailProvider('p1'));
      expect(state.status, CatalogViewStatus.success);
      expect(state.data!.product.id, 'p1');
    });

    test('failure with message when product is missing', () async {
      final container = _container(_IdAwareRepo(missing: {'missing'}));
      pin(container, 'missing');

      await container.read(productDetailProvider('missing').notifier).load();

      final state = container.read(productDetailProvider('missing'));
      expect(state.status, CatalogViewStatus.failure);
      expect(state.message, contains('no longer available'));
    });

    test('A and B instances hold independent state', () async {
      final container = _container(_IdAwareRepo());
      pin(container, 'A');
      pin(container, 'B');

      // Resolve A only.
      await container.read(productDetailProvider('A').notifier).load();

      // B is untouched: its own initial state, not A's data.
      final a = container.read(productDetailProvider('A'));
      final b = container.read(productDetailProvider('B'));
      expect(a.status, CatalogViewStatus.success);
      expect(a.data!.product.id, 'A');
      expect(b.status, CatalogViewStatus.initial);
      expect(b.data, isNull);

      // Resolving B must not alter A.
      await container.read(productDetailProvider('B').notifier).load();
      final aAfter = container.read(productDetailProvider('A'));
      expect(aAfter.data!.product.id, 'A');
      expect(container.read(productDetailProvider('B')).data!.product.id, 'B');
    });

    test('B failure does not overwrite A; retry reruns only B', () async {
      final repo = _IdAwareRepo(failing: {'B'});
      final container = _container(repo);
      pin(container, 'A');
      pin(container, 'B');

      await container.read(productDetailProvider('A').notifier).load();
      await container.read(productDetailProvider('B').notifier).load();

      expect(
        container.read(productDetailProvider('A')).status,
        CatalogViewStatus.success,
      );
      expect(
        container.read(productDetailProvider('B')).status,
        CatalogViewStatus.failure,
      );

      // Retry B only.
      repo.failing.remove('B');
      await container.read(productDetailProvider('B').notifier).load();

      expect(
        container.read(productDetailProvider('B')).status,
        CatalogViewStatus.success,
      );
      // A was loaded once; B twice (initial + retry). A was never re-fetched.
      expect(repo.detailCalls['A'], 1);
      expect(repo.detailCalls['B'], 2);
    });
  });
}
