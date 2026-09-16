import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/categories/data/repositories/supabase_category_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> categoryRow({
  String id = 'c1',
  String? parentId,
  int sortOrder = 0,
}) => {
  'id': id,
  'parent_id': parentId,
  'name': 'Rings $id',
  'slug': 'rings-$id',
  'sort_order': sortOrder,
  'is_active': true,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? throwError;
  List<Map<String, dynamic>> Function(
    String table,
    Map<String, Object?> filters,
  )?
  onList;
  final List<Map<String, Object?>> lastFilters = [];

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
    lastFilters.add(filters);
    return onList?.call(table, filters) ?? const [];
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseCategoryRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseCategoryRepository(database: db);
  });

  test('getCategories returns all active categories', () async {
    db.onList = (table, filters) => [
      categoryRow(id: 'c1'),
      categoryRow(id: 'c2', parentId: 'c1'),
    ];

    final categories = await repo.getCategories();

    expect(categories, hasLength(2));
    expect(categories.first.name, contains('Rings'));
  });

  test(
    'getRootCategories filters to parent-less categories client-side',
    () async {
      db.onList = (table, filters) => [
        categoryRow(id: 'root'),
        categoryRow(id: 'child', parentId: 'root'),
      ];

      final roots = await repo.getRootCategories();

      expect(roots, hasLength(1));
      expect(roots.single.id, 'root');
      expect(roots.single.isRoot, isTrue);
    },
  );

  test('getSubcategories filters by parent_id', () async {
    db.onList = (table, filters) => [
      categoryRow(id: 'child', parentId: 'root'),
    ];

    final subs = await repo.getSubcategories('root');

    expect(subs, hasLength(1));
    expect(db.lastFilters.single['parent_id'], 'root');
  });

  test('getCategoryById returns null when not found', () async {
    db.onList = (table, filters) => const [];
    expect(await repo.getCategoryById('missing'), isNull);
  });

  test('maps failures to Failure', () async {
    db.throwError = const ex.DatabaseException('boom', code: '42P01');
    await expectLater(repo.getCategories(), throwsA(isA<Failure>()));
  });

  group('descendantCategoryIds', () {
    // ROOT ├ CHILD_A ┤ GRANDCHILD  └ CHILD_B  (+ an unrelated OTHER root)
    List<Map<String, dynamic>> tree(String _, Map<String, Object?> _) => [
      categoryRow(id: 'root'),
      categoryRow(id: 'childA', parentId: 'root'),
      categoryRow(id: 'grandchild', parentId: 'childA'),
      categoryRow(id: 'childB', parentId: 'root'),
      categoryRow(id: 'other'),
    ];

    test('returns the root plus every descendant, once', () async {
      db.onList = tree;

      final ids = await repo.descendantCategoryIds('root');

      expect(ids.toSet(), {'root', 'childA', 'grandchild', 'childB'});
      expect(ids, hasLength(4)); // no duplicates
      expect(ids.contains('other'), isFalse); // outside the subtree
    });

    test('a leaf root returns just itself', () async {
      db.onList = tree;
      expect(await repo.descendantCategoryIds('grandchild'), ['grandchild']);
    });

    test('an unknown root returns just itself (no full-catalogue fallback)', () async {
      db.onList = tree;
      expect(await repo.descendantCategoryIds('missing'), ['missing']);
    });

    test('is cycle-safe (visited set prevents infinite traversal)', () async {
      // Defensive: a data cycle a<->b must not hang or duplicate.
      db.onList = (_, _) => [
        categoryRow(id: 'a', parentId: 'b'),
        categoryRow(id: 'b', parentId: 'a'),
      ];

      final ids = await repo.descendantCategoryIds('a');

      expect(ids.toSet(), {'a', 'b'});
      expect(ids, hasLength(2));
    });
  });
}
