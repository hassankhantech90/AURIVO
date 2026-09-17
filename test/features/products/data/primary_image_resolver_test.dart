import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/supabase/supabase_storage_service.dart';
import 'package:aurivo/features/products/data/primary_image_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the arguments of each `list` call and returns scripted rows.
class _Call {
  _Call(this.table, this.columns, this.whereIn, this.orderBy);
  final String table;
  final String columns;
  final Map<String, List<Object>> whereIn;
  final String? orderBy;
}

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  final List<_Call> calls = [];
  List<Map<String, dynamic>> rows = const [];
  Object? throwError;

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
    calls.add(_Call(table, columns, whereIn, orderBy));
    if (throwError != null) throw throwError!;
    return rows;
  }
}

class _FakeStorage extends SupabaseStorageService {
  _FakeStorage() : super(supabaseService: const SupabaseService());

  @override
  String getPublicUrl({required String bucket, required String path}) =>
      'https://cdn.test/$bucket/$path';
}

Map<String, dynamic> row(
  String productId, {
  required String path,
  bool isPrimary = false,
  int sortOrder = 0,
}) => {
  'product_id': productId,
  'storage_path': path,
  'is_primary': isPrimary,
  'sort_order': sortOrder,
};

void main() {
  late _StubDatabase db;
  late PrimaryImageResolver resolver;

  setUp(() {
    db = _StubDatabase();
    resolver = PrimaryImageResolver(database: db, storage: _FakeStorage());
  });

  test('A. empty product ids returns {} and issues no query', () async {
    final result = await resolver.primaryImageUrls(const []);
    expect(result, isEmpty);
    expect(db.calls, isEmpty);
  });

  test('B. N product ids issue exactly one product_images query', () async {
    db.rows = [row('p1', path: 'p1/a.jpg')];
    await resolver.primaryImageUrls(['p1', 'p2', 'p3']);
    expect(db.calls, hasLength(1));
    expect(db.calls.single.table, 'product_images');
    expect(db.calls.single.orderBy, 'sort_order');
  });

  test('C. duplicate product ids are deduplicated in the query', () async {
    db.rows = const [];
    await resolver.primaryImageUrls(['p1', 'p1', 'p2', 'p2', 'p2']);
    expect(db.calls.single.whereIn['product_id'], hasLength(2));
    expect(db.calls.single.whereIn['product_id'], containsAll(['p1', 'p2']));
  });

  test('D. a primary image is preferred over an earlier non-primary', () async {
    db.rows = [
      row('p1', path: 'p1/gallery.jpg', sortOrder: 0),
      row('p1', path: 'p1/hero.jpg', isPrimary: true, sortOrder: 1),
    ];
    final result = await resolver.primaryImageUrls(['p1']);
    expect(result['p1'], 'https://cdn.test/product-images/p1/hero.jpg');
  });

  test('E. multiple primaries resolve to the first by sort order', () async {
    db.rows = [
      row('p1', path: 'p1/a.jpg', sortOrder: 0),
      row('p1', path: 'p1/b.jpg', isPrimary: true, sortOrder: 1),
      row('p1', path: 'p1/c.jpg', isPrimary: true, sortOrder: 2),
    ];
    final result = await resolver.primaryImageUrls(['p1']);
    expect(result['p1'], 'https://cdn.test/product-images/p1/b.jpg');
  });

  test('F. no primary falls back to the first by sort order', () async {
    db.rows = [
      row('p1', path: 'p1/a.jpg', sortOrder: 0),
      row('p1', path: 'p1/b.jpg', sortOrder: 1),
    ];
    final result = await resolver.primaryImageUrls(['p1']);
    expect(result['p1'], 'https://cdn.test/product-images/p1/a.jpg');
  });

  test('G. a product with no image row has no map entry', () async {
    db.rows = [row('p1', path: 'p1/a.jpg')];
    final result = await resolver.primaryImageUrls(['p1', 'p2']);
    expect(result.containsKey('p1'), isTrue);
    expect(result.containsKey('p2'), isFalse);
  });

  test('H. storage_path is converted to a public URL', () async {
    db.rows = [row('p1', path: 'p1/ring.jpg')];
    final result = await resolver.primaryImageUrls(['p1']);
    expect(result['p1'], 'https://cdn.test/product-images/p1/ring.jpg');
  });

  test('I. only explicit safe image columns are requested', () async {
    db.rows = const [];
    await resolver.primaryImageUrls(['p1']);
    final columns = db.calls.single.columns;
    expect(columns, contains('product_id'));
    expect(columns, contains('storage_path'));
    expect(columns, contains('is_primary'));
    expect(columns, contains('sort_order'));
    expect(columns, isNot(contains('*')));
    expect(columns, isNot(contains('alt_text')));
  });
}
