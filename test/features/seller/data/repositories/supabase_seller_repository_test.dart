import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/supabase/supabase_storage_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/products/data/primary_image_resolver.dart';
import 'package:aurivo/features/seller/data/repositories/supabase_seller_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sellerRow({
  String id = 's1',
  String slug = 'gold-house',
  String status = 'verified',
}) => {
  'id': id,
  'profile_id': 'p1',
  'store_name': 'Gold House',
  'slug': slug,
  'verification_status': status,
  'is_wholesale_enabled': false,
  'rating_average': 0,
  'rating_count': 0,
};

Map<String, dynamic> productRow({String id = 'prod-1'}) => {
  'id': id,
  'seller_id': 's1',
  'title': 'Ring',
  'slug': 'ring-$id',
  'jewellery_type': 'ring',
  'base_price': 1000,
  'status': 'approved',
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? throwError;
  List<Map<String, dynamic>> Function(
    String table,
    Map<String, Object?> filters,
  )?
  onList;

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
    return onList?.call(table, filters) ?? const [];
  }
}

class _FakeStorage extends SupabaseStorageService {
  _FakeStorage() : super(supabaseService: const SupabaseService());

  @override
  String getPublicUrl({required String bucket, required String path}) =>
      'https://cdn.test/$bucket/$path';
}

void main() {
  late _StubDatabase db;
  late SupabaseSellerRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseSellerRepository(
      database: db,
      imageResolver: PrimaryImageResolver(
        database: db,
        storage: _FakeStorage(),
      ),
    );
  });

  test('getVerifiedSellers filters by verified status', () async {
    Map<String, Object?>? seen;
    db.onList = (table, filters) {
      seen = filters;
      return [sellerRow(id: 'a'), sellerRow(id: 'b')];
    };

    final sellers = await repo.getVerifiedSellers();

    expect(sellers, hasLength(2));
    expect(seen!['verification_status'], 'verified');
  });

  test('getSellerBySlug filters by slug + verified and returns one', () async {
    Map<String, Object?>? seen;
    db.onList = (table, filters) {
      seen = filters;
      return [sellerRow(slug: 'gold-house')];
    };

    final seller = await repo.getSellerBySlug('gold-house');

    expect(seller, isNotNull);
    expect(seller!.slug, 'gold-house');
    expect(seen!['slug'], 'gold-house');
    expect(seen!['verification_status'], 'verified');
  });

  test('getSellerBySlug returns null when not visible', () async {
    db.onList = (table, filters) => const [];
    expect(await repo.getSellerBySlug('missing'), isNull);
  });

  test('getSellerProducts filters by seller and approved status', () async {
    Map<String, Object?>? productFilters;
    var imageQueries = 0;
    db.onList = (table, filters) {
      if (table == 'product_images') {
        imageQueries++;
        return [
          {
            'product_id': 'a',
            'storage_path': 'a/hero.jpg',
            'is_primary': true,
            'sort_order': 0,
          },
        ];
      }
      productFilters = filters;
      return [productRow(id: 'a'), productRow(id: 'b')];
    };

    final products = await repo.getSellerProducts('s1');

    expect(products, hasLength(2));
    expect(productFilters!['seller_id'], 's1');
    expect(productFilters!['status'], 'approved');
    // A single batch image query enriches the whole storefront page (no N+1).
    expect(imageQueries, 1);
    expect(
      products.firstWhere((p) => p.id == 'a').primaryImageUrl,
      'https://cdn.test/product-images/a/hero.jpg',
    );
    expect(products.firstWhere((p) => p.id == 'b').primaryImageUrl, isNull);
  });

  test('maps a database exception to a Failure', () async {
    db.throwError = const ex.DatabaseException('boom', code: '42P01');
    await expectLater(repo.getVerifiedSellers(), throwsA(isA<Failure>()));
  });
}
