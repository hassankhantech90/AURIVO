import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/supabase/supabase_storage_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/products/data/primary_image_resolver.dart';
import 'package:aurivo/features/products/data/repositories/supabase_product_repository.dart';
import 'package:aurivo/features/products/domain/entities/product_sort.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> productRow({String id = 'p1', String? brandId}) => {
  'id': id,
  'seller_id': 'seller-1',
  'brand_id': brandId,
  'title': 'Gold Ring $id',
  'slug': 'gold-ring-$id',
  'jewellery_type': 'ring',
  'currency': 'PKR',
  'base_price': 15000,
  'compare_price': 18000,
  'featured': false,
  'rating_average': 4.5,
  'rating_count': 12,
};

Map<String, dynamic> imageRow({String id = 'img1', bool isPrimary = false}) => {
  'id': id,
  'product_id': 'p1',
  'storage_path': 'p1/$id.jpg',
  'is_primary': isPrimary,
  'sort_order': 0,
};

Map<String, dynamic> variantRow({String id = 'v1', num price = 15000}) => {
  'id': id,
  'product_id': 'p1',
  'price': price,
  'currency': 'PKR',
  'is_active': true,
};

Map<String, dynamic> brandRow({String id = 'b1'}) => {
  'id': id,
  'name': 'Aurivo',
  'slug': 'aurivo',
  'status': 'active',
};

class _Query {
  _Query(
    this.table,
    this.columns,
    this.filters,
    this.whereIn,
    this.orderBy,
    this.ascending,
    this.limit,
    this.offset,
  );
  final String table;
  final String columns;
  final Map<String, Object?> filters;
  final Map<String, List<Object>> whereIn;
  final String? orderBy;
  final bool ascending;
  final int? limit;
  final int? offset;
}

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? throwError;
  List<Map<String, dynamic>> Function(String table, _Query query)? onList;
  final List<_Query> queries = [];

  @override
  Future<List<Map<String, dynamic>>> list({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
    Map<String, List<Object>> whereIn = const {},
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    if (throwError != null) throw throwError!;
    final q = _Query(
      table,
      columns,
      filters,
      whereIn,
      orderBy,
      ascending,
      limit,
      offset,
    );
    queries.add(q);
    return onList?.call(table, q) ?? const [];
  }
}

/// Builds a deterministic, offline public URL from a storage path.
class _FakeStorage extends SupabaseStorageService {
  _FakeStorage() : super(supabaseService: const SupabaseService());

  @override
  String getPublicUrl({required String bucket, required String path}) =>
      'https://cdn.test/$bucket/$path';
}

void main() {
  late _StubDatabase db;
  late SupabaseProductRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseProductRepository(
      database: db,
      imageResolver: PrimaryImageResolver(
        database: db,
        storage: _FakeStorage(),
      ),
    );
  });

  // Products query for tests that also trigger the batch product_images query.
  _Query productsQuery() => db.queries.firstWhere((q) => q.table == 'products');

  group('getProducts', () {
    test(
      'returns products with default newest ordering + pagination',
      () async {
        db.onList = (table, q) => [productRow(id: 'p1'), productRow(id: 'p2')];

        final products = await repo.getProducts(limit: 20, offset: 0);

        expect(products, hasLength(2));
        expect(products.first.title, contains('Gold Ring'));
        final q = productsQuery();
        expect(q.table, 'products');
        expect(q.orderBy, 'created_at');
        expect(q.ascending, isFalse);
        expect(q.limit, 20);
        expect(q.offset, 0);
      },
    );

    test('filters by brand', () async {
      db.onList = (table, q) => [productRow(brandId: 'b1')];

      await repo.getProductsByBrand('b1');

      expect(productsQuery().filters['brand_id'], 'b1');
    });

    test('price sort maps to base_price ascending', () async {
      db.onList = (table, q) => const [];
      await repo.getProducts(sort: ProductSort.priceLowToHigh);
      expect(db.queries.single.orderBy, 'base_price');
      expect(db.queries.single.ascending, isTrue);
    });
  });

  group('getProducts by category set (categoryIds)', () {
    test('maps a category-id set to unique product ids via IN filters', () async {
      db.onList = (table, q) {
        if (table == 'product_categories') {
          // p1 appears under two subtree categories -> must dedupe.
          return [
            {'product_id': 'p1'},
            {'product_id': 'p1'},
            {'product_id': 'p2'},
          ];
        }
        return [productRow(id: 'p1'), productRow(id: 'p2')];
      };

      final products = await repo.getProducts(
        categoryIds: ['root', 'childA', 'grandchild'],
      );

      expect(products, hasLength(2)); // deduped
      final mappingQuery = db.queries.firstWhere(
        (q) => q.table == 'product_categories',
      );
      expect(mappingQuery.whereIn['category_id'], [
        'root',
        'childA',
        'grandchild',
      ]);
      final productsQuery = db.queries.firstWhere((q) => q.table == 'products');
      expect(productsQuery.whereIn['id'], containsAll(['p1', 'p2']));
      expect(productsQuery.whereIn['id'], hasLength(2)); // unique
      // Final ordering/limit stays on the products query.
      expect(productsQuery.orderBy, 'created_at');
    });

    test('empty categoryIds returns [] and issues no query', () async {
      final products = await repo.getProducts(categoryIds: const []);
      expect(products, isEmpty);
      expect(db.queries, isEmpty);
    });

    test('no mapped products returns [] and skips the products query', () async {
      db.onList = (table, q) => const []; // no product_categories rows
      final products = await repo.getProducts(categoryIds: ['root']);
      expect(products, isEmpty);
      expect(db.queries.any((q) => q.table == 'products'), isFalse);
    });

    test('categoryIds takes precedence over categoryId', () async {
      db.onList = (table, q) {
        if (table == 'product_categories') return [{'product_id': 'p1'}];
        return [productRow(id: 'p1')];
      };

      await repo.getProducts(categoryId: 'single', categoryIds: ['a', 'b']);

      final mappingQuery = db.queries.firstWhere(
        (q) => q.table == 'product_categories',
      );
      // The set path was used (IN), not the single-category eq path.
      expect(mappingQuery.whereIn['category_id'], ['a', 'b']);
      expect(mappingQuery.filters.containsKey('category_id'), isFalse);
    });
  });

  group('getProductsByCategory', () {
    test('resolves product ids then queries products via IN filter', () async {
      db.onList = (table, q) {
        if (table == 'product_categories') {
          return [
            {'product_id': 'p1'},
            {'product_id': 'p2'},
          ];
        }
        return [productRow(id: 'p1'), productRow(id: 'p2')];
      };

      final products = await repo.getProductsByCategory('c1');

      expect(products, hasLength(2));
      final productsQuery = db.queries.firstWhere((q) => q.table == 'products');
      expect(productsQuery.whereIn['id'], ['p1', 'p2']);
    });

    test(
      'returns empty and skips product query when category has none',
      () async {
        db.onList = (table, q) => const []; // no product_categories rows

        final products = await repo.getProductsByCategory('c1');

        expect(products, isEmpty);
        expect(db.queries.any((q) => q.table == 'products'), isFalse);
      },
    );
  });

  group('getProductById', () {
    test('returns a product', () async {
      db.onList = (table, q) => [productRow()];
      final product = await repo.getProductById('p1');
      expect(product, isNotNull);
      expect(product!.id, 'p1');
    });

    test('returns null when not found/visible', () async {
      db.onList = (table, q) => const [];
      expect(await repo.getProductById('missing'), isNull);
    });
  });

  group('getProductsByIds', () {
    test('queries products via an IN filter and parses rows', () async {
      db.onList = (table, q) => [productRow(id: 'p1'), productRow(id: 'p2')];

      final products = await repo.getProductsByIds(['p1', 'p2']);

      expect(products.map((p) => p.id), ['p1', 'p2']);
      final q = productsQuery();
      expect(q.table, 'products');
      expect(q.whereIn['id'], ['p1', 'p2']);
    });

    test('returns empty and skips the query for empty input', () async {
      final products = await repo.getProductsByIds(const []);
      expect(products, isEmpty);
      expect(db.queries, isEmpty);
    });
  });

  group('getProductDetail', () {
    test('composes product, images and variants', () async {
      db.onList = (table, q) {
        switch (table) {
          case 'products':
            return [productRow()];
          case 'product_images':
            return [imageRow(id: 'img1', isPrimary: true)];
          case 'product_variants':
            return [variantRow(id: 'v1'), variantRow(id: 'v2', price: 20000)];
          default:
            return const [];
        }
      };

      final detail = await repo.getProductDetail('p1');

      expect(detail, isNotNull);
      expect(detail!.product.id, 'p1');
      expect(detail.images, hasLength(1));
      expect(detail.variants, hasLength(2));
      expect(detail.primaryImage?.id, 'img1');
      // The hero is resolved to a public URL, and no extra image query is made
      // (the already-loaded images are reused): products, images, variants only.
      expect(
        detail.product.primaryImageUrl,
        'https://cdn.test/product-images/p1/img1.jpg',
      );
      expect(
        db.queries.where((q) => q.table == 'product_images'),
        hasLength(1),
      );
      expect(db.queries, hasLength(3));
    });

    test('falls back to the first image by sort order when no primary', () async {
      db.onList = (table, q) {
        switch (table) {
          case 'products':
            return [productRow()];
          case 'product_images':
            return [imageRow(id: 'first'), imageRow(id: 'second')];
          default:
            return const [];
        }
      };

      final detail = await repo.getProductDetail('p1');

      expect(
        detail!.product.primaryImageUrl,
        'https://cdn.test/product-images/p1/first.jpg',
      );
    });

    test('leaves primaryImageUrl null when the product has no images', () async {
      db.onList = (table, q) =>
          table == 'products' ? [productRow()] : const [];

      final detail = await repo.getProductDetail('p1');

      expect(detail!.images, isEmpty);
      expect(detail.product.primaryImageUrl, isNull);
    });

    test('returns null when the product does not exist', () async {
      db.onList = (table, q) => const [];
      expect(await repo.getProductDetail('missing'), isNull);
    });
  });

  group('variants', () {
    test('selects only buyer-facing columns (no sku/barcode/stock)', () async {
      db.onList = (table, q) => [variantRow()];

      final variants = await repo.getProductVariants('p1');

      expect(variants, hasLength(1));
      expect(variants.first.price, 15000);
      final cols = db.queries.single.columns;
      expect(cols, contains('price'));
      expect(cols, isNot(contains('sku')));
      expect(cols, isNot(contains('barcode')));
      expect(cols, isNot(contains('stock_quantity')));
    });
  });

  group('images', () {
    test('parses and orders by sort_order', () async {
      db.onList = (table, q) => [imageRow(id: 'a'), imageRow(id: 'b')];
      final images = await repo.getProductImages('p1');
      expect(images, hasLength(2));
      expect(db.queries.single.orderBy, 'sort_order');
    });
  });

  group('brands & attributes', () {
    test('getBrands returns brands ordered by name', () async {
      db.onList = (table, q) => [brandRow()];
      final brands = await repo.getBrands();
      expect(brands.single.name, 'Aurivo');
      expect(db.queries.single.orderBy, 'name');
    });

    test('getAttributes with filterableOnly adds the filter', () async {
      db.onList = (table, q) => const [];
      await repo.getAttributes(filterableOnly: true);
      expect(db.queries.single.filters['is_filterable'], true);
    });
  });

  group('primary image enrichment', () {
    Map<String, dynamic> imgRow(
      String productId, {
      String id = 'i',
      bool isPrimary = false,
      int sortOrder = 0,
    }) => {
      'product_id': productId,
      'storage_path': '$productId/$id.jpg',
      'is_primary': isPrimary,
      'sort_order': sortOrder,
    };

    test('getProducts enriches primaryImageUrl from one batch query', () async {
      db.onList = (table, q) {
        if (table == 'product_images') {
          return [imgRow('p1', id: 'a'), imgRow('p2', id: 'b')];
        }
        return [productRow(id: 'p1'), productRow(id: 'p2')];
      };

      final products = await repo.getProducts();

      expect(
        products.firstWhere((p) => p.id == 'p1').primaryImageUrl,
        'https://cdn.test/product-images/p1/a.jpg',
      );
      expect(
        products.firstWhere((p) => p.id == 'p2').primaryImageUrl,
        'https://cdn.test/product-images/p2/b.jpg',
      );
      // Exactly one product_images query for the whole page (no N+1).
      expect(
        db.queries.where((q) => q.table == 'product_images'),
        hasLength(1),
      );
    });

    test('getProductsByIds enriches primaryImageUrl', () async {
      db.onList = (table, q) {
        if (table == 'product_images') return [imgRow('p1', id: 'a')];
        return [productRow(id: 'p1')];
      };

      final products = await repo.getProductsByIds(['p1']);

      expect(
        products.single.primaryImageUrl,
        'https://cdn.test/product-images/p1/a.jpg',
      );
    });

    test('a product with no image keeps primaryImageUrl null', () async {
      db.onList = (table, q) {
        if (table == 'product_images') return [imgRow('p1', id: 'a')];
        return [productRow(id: 'p1'), productRow(id: 'p2')];
      };

      final products = await repo.getProducts();

      expect(products.firstWhere((p) => p.id == 'p1').primaryImageUrl, isNotNull);
      expect(products.firstWhere((p) => p.id == 'p2').primaryImageUrl, isNull);
    });

    test('empty products result triggers no image batch query', () async {
      db.onList = (table, q) => const [];

      final products = await repo.getProducts();

      expect(products, isEmpty);
      expect(db.queries.any((q) => q.table == 'product_images'), isFalse);
    });

    test('image batch failure degrades to null urls, not a load error', () async {
      db.onList = (table, q) {
        if (table == 'product_images') {
          throw const ex.NetworkException('images offline');
        }
        return [productRow(id: 'p1')];
      };

      final products = await repo.getProducts();

      expect(products, hasLength(1));
      expect(products.single.primaryImageUrl, isNull);
    });
  });

  group('failures & empty', () {
    test('maps a database exception to a Failure', () async {
      db.throwError = const ex.DatabaseException('boom', code: '42P01');
      await expectLater(repo.getProducts(), throwsA(isA<Failure>()));
    });

    test('never surfaces a raw Supabase exception', () async {
      db.throwError = const ex.NetworkException('offline');
      await expectLater(
        repo.getBrands(),
        throwsA(
          predicate((e) => e is Failure && e is! ex.AppSupabaseException),
        ),
      );
    });

    test('returns empty list when there are no products', () async {
      db.onList = (table, q) => const [];
      expect(await repo.getProducts(), isEmpty);
    });
  });
}
