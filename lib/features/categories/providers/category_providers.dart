import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../products/providers/catalog_state.dart';
import '../data/repositories/supabase_category_repository.dart';
import '../domain/entities/category.dart';
import '../domain/repositories/category_repository.dart';

/// Repository binding for the category catalogue (lazy service — stays
/// test-safe without an initialized Supabase client).
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return SupabaseCategoryRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, CatalogState<List<Category>>>((
      ref,
    ) {
      return CategoriesNotifier(ref.watch(categoryRepositoryProvider));
    });

class CategoriesNotifier extends StateNotifier<CatalogState<List<Category>>> {
  CategoriesNotifier(this._repository)
    : super(const CatalogState<List<Category>>()) {
    _runner = CatalogRunner<List<Category>>(
      () => state,
      (value) => state = value,
    );
  }

  final CategoryRepository _repository;
  late final CatalogRunner<List<Category>> _runner;

  /// Loads all active categories.
  Future<void> load() => _runner.run(_repository.getCategories);

  /// Loads only top-level categories.
  Future<void> loadRoots() => _runner.run(_repository.getRootCategories);
}
