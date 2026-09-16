import '../../../../core/supabase/supabase_database_service.dart';
import '../../../products/data/catalog_failure_mapper.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';

/// Supabase-backed read-only [CategoryRepository]. RLS returns only active,
/// non-deleted categories.
class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _table = 'categories';

  @override
  Future<List<Category>> getCategories() async {
    try {
      final rows = await _database.list(table: _table, orderBy: 'sort_order');
      return rows.map(Category.fromMap).toList();
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<List<Category>> getRootCategories() async {
    // parent_id IS NULL cannot be expressed as an equality filter, so filter
    // the full (RLS-limited) active set client-side.
    final categories = await getCategories();
    return categories.where((category) => category.isRoot).toList();
  }

  @override
  Future<List<Category>> getSubcategories(String parentId) async {
    try {
      final rows = await _database.list(
        table: _table,
        filters: {'parent_id': parentId},
        orderBy: 'sort_order',
      );
      return rows.map(Category.fromMap).toList();
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    try {
      final rows = await _database.list(
        table: _table,
        filters: {'id': id},
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Category.fromMap(rows.first);
    } catch (error) {
      throw CatalogFailureMapper.map(error);
    }
  }

  @override
  Future<List<String>> descendantCategoryIds(String rootId) async {
    // Fetch the visible tree once, then traverse locally (no per-level query).
    final categories = await getCategories();
    final childrenByParent = <String, List<String>>{};
    for (final category in categories) {
      final parentId = category.parentId;
      if (parentId != null) {
        (childrenByParent[parentId] ??= <String>[]).add(category.id);
      }
    }

    // BFS from the root; the visited set both dedupes and guards against cycles.
    final result = <String>[];
    final visited = <String>{};
    final queue = <String>[rootId];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (!visited.add(id)) continue;
      result.add(id);
      final children = childrenByParent[id];
      if (children != null) queue.addAll(children);
    }
    return result;
  }
}
