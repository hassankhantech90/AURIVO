import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/seller/data/repositories/supabase_seller_product_repository.dart';
import 'package:aurivo/features/seller/domain/entities/product_draft.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> productRow({
  String id = 'prod-1',
  String status = 'draft',
  String? deletedAt,
}) => {
  'id': id,
  'seller_id': 'sp-1',
  'title': 'Ring',
  'slug': 'ring',
  'jewellery_type': 'ring',
  'base_price': 1000,
  'currency': 'PKR',
  'status': status,
  'featured': false,
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? rpcResult = 'profile-1';
  Object? insertError;
  List<Map<String, dynamic>> Function(
    String table,
    Map<String, Object?> filters,
  )?
  onList;

  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<Map<String, Object?>> deleted = [];

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
    return onList?.call(table, filters) ?? const [];
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add({'_table': table, ...values});
    return {'id': 'prod-new', 'status': 'draft', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_match': '$matchColumn=$matchValue', ...values});
    return {...productRow(id: matchValue as String), ...values};
  }

  @override
  Future<void> delete({
    required String table,
    required String matchColumn,
    required Object matchValue,
  }) async {
    deleted.add({'_table': table, matchColumn: matchValue});
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    return rpcResult;
  }
}

// Convenience: make list() resolve the seller profile then the requested table.
void _wireSeller(_StubDatabase db, {List<Map<String, dynamic>>? products}) {
  db.onList = (table, filters) {
    switch (table) {
      case 'seller_profiles':
        return [
          {'id': 'sp-1', 'profile_id': 'profile-1'},
        ];
      case 'products':
        return products ?? [productRow()];
      case 'product_categories':
        return [
          {'category_id': 'cat-1'},
        ];
      default:
        return const [];
    }
  };
}

void main() {
  late _StubDatabase db;
  late SupabaseSellerProductRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseSellerProductRepository(database: db);
  });

  test('mySellerProfileId resolves via current profile', () async {
    _wireSeller(db);
    expect(await repo.mySellerProfileId(), 'sp-1');
  });

  test('mySellerProfileId is null for a non-seller', () async {
    db.onList = (table, filters) => const [];
    expect(await repo.mySellerProfileId(), isNull);
  });

  test('getMyProducts filters by seller and hides soft-deleted', () async {
    _wireSeller(
      db,
      products: [
        productRow(id: 'a'),
        productRow(id: 'b', deletedAt: '2026-01-01T00:00:00Z'),
      ],
    );
    final products = await repo.getMyProducts();
    expect(products.map((p) => p.id), ['a']); // deleted 'b' excluded
  });

  test(
    'createProduct sets server-resolved seller_id and never status',
    () async {
      _wireSeller(db);
      await repo.createProduct(
        const ProductDraft(
          title: 'Ring',
          slug: 'ring',
          jewelleryType: 'ring',
          basePrice: 1000,
          categoryIds: ['cat-1', 'cat-2'],
        ),
      );

      final productInsert = db.inserted.firstWhere(
        (v) => v['_table'] == 'products',
      );
      expect(productInsert['seller_id'], 'sp-1'); // server-derived
      expect(productInsert.containsKey('status'), isFalse); // defaults to draft
      // Category links inserted.
      final catInserts = db.inserted.where(
        (v) => v['_table'] == 'product_categories',
      );
      expect(catInserts.length, 2);
    },
  );

  test('createProduct requires a seller store', () async {
    db.onList = (table, filters) => const []; // no seller profile
    await expectLater(
      repo.createProduct(
        const ProductDraft(
          title: 'X',
          slug: 'x',
          jewelleryType: 'ring',
          basePrice: 1,
        ),
      ),
      throwsA(isA<Failure>()),
    );
  });

  test(
    'createProduct maps a duplicate slug (23505) to a friendly failure',
    () async {
      _wireSeller(db);
      db.insertError = const ex.DatabaseException('dup', code: '23505');
      await expectLater(
        repo.createProduct(
          const ProductDraft(
            title: 'X',
            slug: 'x',
            jewelleryType: 'ring',
            basePrice: 1,
          ),
        ),
        throwsA(
          isA<Failure>().having((f) => f.message, 'message', contains('slug')),
        ),
      );
    },
  );

  test('setPublished submits for review (pending) or withdraws (draft)', () async {
    // Sellers can no longer self-approve; publishing submits for admin review.
    _wireSeller(db);
    await repo.setPublished('prod-1', true);
    expect(db.updated.last['status'], 'pending');
    await repo.setPublished('prod-1', false);
    expect(db.updated.last['status'], 'draft');
  });

  test('softDelete sets deleted_at', () async {
    _wireSeller(db);
    await repo.softDelete('prod-1');
    expect(db.updated.single['_match'], 'id=prod-1');
    expect(db.updated.single['deleted_at'], isNotNull);
  });

  test('updateProduct replaces category assignments', () async {
    _wireSeller(db);
    await repo.updateProduct(
      'prod-1',
      const ProductDraft(
        title: 'Ring',
        slug: 'ring',
        jewelleryType: 'ring',
        basePrice: 1000,
        categoryIds: ['cat-9'],
      ),
    );
    // Old categories cleared then new one inserted.
    expect(db.deleted.any((d) => d['_table'] == 'product_categories'), isTrue);
    expect(
      db.inserted.where((v) => v['_table'] == 'product_categories').length,
      1,
    );
  });
}
