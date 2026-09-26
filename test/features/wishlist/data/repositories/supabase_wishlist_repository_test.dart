import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/wishlist/data/repositories/supabase_wishlist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> wishlistRow({
  String id = 'w1',
  String profileId = 'profile-1',
  String productId = 'prod-1',
}) => {
  'id': id,
  'profile_id': profileId,
  'product_id': productId,
  'created_at': '2026-01-01T00:00:00Z',
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? rpcResult = 'profile-1';
  Object? throwError;
  Object? insertError;
  List<Map<String, dynamic>> Function(Map<String, Object?> filters)? onList;

  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, Object?>> deleted = [];

  @override
  Future<List<Map<String, dynamic>>> list({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
    Map<String, List<Object>> whereIn = const {},
    String? ilikeColumn,
    String? ilikeQuery,
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    if (throwError != null) throw throwError!;
    return onList?.call(filters) ?? const [];
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add(values);
    return {'id': 'w1', 'created_at': '2026-01-01T00:00:00Z', ...values};
  }

  @override
  Future<void> delete({
    required String table,
    required String matchColumn,
    required Object matchValue,
  }) async {
    if (throwError != null) throw throwError!;
    deleted.add({matchColumn: matchValue});
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    if (throwError != null) throw throwError!;
    return rpcResult;
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseWishlistRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseWishlistRepository(database: db);
  });

  test('getWishlist returns the user items', () async {
    db.onList = (filters) => [
      wishlistRow(productId: 'a'),
      wishlistRow(productId: 'b'),
    ];
    final items = await repo.getWishlist();
    expect(items, hasLength(2));
    expect(items.first.productId, 'a');
  });

  test('getWishlistedProductIds returns a set of ids', () async {
    db.onList = (filters) => [
      wishlistRow(productId: 'a'),
      wishlistRow(productId: 'b'),
    ];
    expect(await repo.getWishlistedProductIds(), {'a', 'b'});
  });

  test('isWishlisted reflects presence', () async {
    db.onList = (filters) => [wishlistRow(productId: 'prod-1')];
    expect(await repo.isWishlisted('prod-1'), isTrue);

    db.onList = (filters) => const [];
    expect(await repo.isWishlisted('prod-2'), isFalse);
  });

  test('add inserts when the product is absent', () async {
    db.onList = (filters) => const []; // not present
    final item = await repo.add('prod-1');
    expect(db.inserted, hasLength(1));
    expect(db.inserted.single['profile_id'], 'profile-1');
    expect(db.inserted.single['product_id'], 'prod-1');
    expect(item.productId, 'prod-1');
  });

  test('add is idempotent when already present (no insert)', () async {
    db.onList = (filters) => [wishlistRow(productId: 'prod-1')];
    final item = await repo.add('prod-1');
    expect(db.inserted, isEmpty);
    expect(item.productId, 'prod-1');
  });

  test('add tolerates a concurrent duplicate insert (23505)', () async {
    var calls = 0;
    db.onList = (filters) =>
        calls++ == 0 ? const [] : [wishlistRow(productId: 'prod-1')];
    db.insertError = const ex.DatabaseException('duplicate', code: '23505');

    final item = await repo.add('prod-1');

    expect(item.productId, 'prod-1');
  });

  test('remove deletes by product id (RLS scopes to the owner)', () async {
    await repo.remove('prod-1');
    expect(db.deleted.single['product_id'], 'prod-1');
  });

  test('requires authentication when there is no profile', () async {
    db.rpcResult = null;
    await expectLater(repo.getWishlist(), throwsA(isA<Failure>()));
  });

  test('maps a database exception to a Failure', () async {
    db.throwError = const ex.DatabaseException('boom', code: '42P01');
    await expectLater(repo.getWishlist(), throwsA(isA<Failure>()));
  });
}
