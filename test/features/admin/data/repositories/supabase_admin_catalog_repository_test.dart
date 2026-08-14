import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/data/repositories/supabase_admin_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> categoryRow({
  String id = 'c1',
  String? deletedAt,
  String slug = 'rings',
}) => {
  'id': id,
  'parent_id': null,
  'name': 'Rings',
  'slug': slug,
  'sort_order': 0,
  'is_active': true,
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? insertError;
  List<Map<String, dynamic>> Function(String table, Map<String, Object?> filters)?
  onList;
  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];

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
  }) async => onList?.call(table, filters) ?? const [];

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add({'_table': table, ...values});
    return {'id': 'new', 'name': 'X', 'slug': 'x', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_table': table, '_match': '$matchColumn=$matchValue', ...values});
    return {'id': matchValue, 'name': 'X', 'slug': 'x', ...values};
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseAdminCatalogRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseAdminCatalogRepository(database: db);
  });

  test('listCategories excludes soft-deleted rows', () async {
    db.onList = (table, filters) => [
      categoryRow(id: 'live'),
      categoryRow(id: 'dead', deletedAt: '2026-08-14T00:00:00Z'),
    ];
    final cats = await repo.listCategories();
    expect(cats.map((c) => c.id), ['live']);
  });

  test('createCategory trims and passes fields', () async {
    await repo.createCategory(name: '  Rings ', slug: ' rings ', sortOrder: 2);
    final row = db.inserted.single;
    expect(row['_table'], 'categories');
    expect(row['name'], 'Rings');
    expect(row['slug'], 'rings');
    expect(row['sort_order'], 2);
  });

  test('updateCategory omits nulls and clears parent when asked', () async {
    await repo.updateCategory(id: 'c1', name: 'Necklaces', clearParent: true);
    final row = db.updated.single;
    expect(row['name'], 'Necklaces');
    expect(row.containsKey('slug'), isFalse); // null -> omitted
    expect(row.containsKey('parent_id'), isTrue);
    expect(row['parent_id'], isNull); // explicitly cleared
  });

  test('deleteCategory soft-deletes and deactivates', () async {
    await repo.deleteCategory('c1');
    final row = db.updated.single;
    expect(row['_match'], 'id=c1');
    expect(row['deleted_at'], isNotNull);
    expect(row['is_active'], isFalse);
  });

  test('deleteBrand archives and soft-deletes', () async {
    await repo.deleteBrand('b1');
    final row = db.updated.single;
    expect(row['deleted_at'], isNotNull);
    expect(row['status'], 'archived');
  });

  test('listAttributeValues filters by attribute id', () async {
    db.onList = (table, filters) {
      expect(table, 'attribute_values');
      expect(filters['attribute_id'], 'attr1');
      return [
        {'id': 'v1', 'attribute_id': 'attr1', 'value': 'Gold', 'sort_order': 0},
      ];
    };
    final values = await repo.listAttributeValues('attr1');
    expect(values.single.value, 'Gold');
  });

  test('maps a duplicate slug (23505) to a Failure', () async {
    db.insertError = const ex.DatabaseException('dup', code: '23505');
    await expectLater(
      repo.createBrand(name: 'Aurum', slug: 'aurum'),
      throwsA(predicate((e) => e is Failure && e.code == '23505')),
    );
  });
}
