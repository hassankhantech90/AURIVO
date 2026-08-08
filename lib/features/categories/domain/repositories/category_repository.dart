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
}
