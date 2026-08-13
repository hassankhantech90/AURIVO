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
  _FakeProductRepository({this.products = const [], this.detail, this.error});

  final List<Product> products;
  final ProductDetail? detail;
  final Object? error;

  @override
  Future<List<Product>> getProducts({
    int limit = 20,
    int offset = 0,
    String? brandId,
    String? categoryId,
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
    return detail;
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
    test('success when detail is found', () async {
      final container = _container(
        _FakeProductRepository(detail: ProductDetail(product: _product('p1'))),
      );

      await container.read(productDetailProvider.notifier).load('p1');

      final state = container.read(productDetailProvider);
      expect(state.status, CatalogViewStatus.success);
      expect(state.data!.product.id, 'p1');
    });

    test('failure with message when product is missing', () async {
      final container = _container(_FakeProductRepository(detail: null));

      await container.read(productDetailProvider.notifier).load('missing');

      final state = container.read(productDetailProvider);
      expect(state.status, CatalogViewStatus.failure);
      expect(state.message, contains('no longer available'));
    });
  });
}
