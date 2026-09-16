import '../entities/category.dart';

/// Read-only contract for the public category catalogue. Relies on existing RLS
/// (only active, non-deleted categories are returned) and throws the shared
/// `Failure` type rather than raw Supabase exceptions.
abstract class CategoryRepository {
  /// All active categories, ordered by [Category.sortOrder].
  Future<List<Category>> getCategories();

  /// Top-level categories only (`parent_id is null`).
  Future<List<Category>> getRootCategories();

  /// Direct children of [parentId].
  Future<List<Category>> getSubcategories(String parentId);

  Future<Category?> getCategoryById(String id);

  /// [rootId] plus every reachable descendant id, over the currently visible
  /// category tree (see [getCategories] — RLS-active, non-deleted only). An
  /// unknown root resolves to `[rootId]`. Never falls back to the full
  /// catalogue; a subtree hidden behind an inactive/deleted intermediate node
  /// is intentionally unreachable (consistent with category visibility).
  Future<List<String>> descendantCategoryIds(String rootId);
}
