import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/categories/domain/entities/category.dart';
import 'package:aurivo/features/categories/domain/repositories/category_repository.dart';
import 'package:aurivo/features/categories/providers/category_providers.dart';
import 'package:aurivo/features/products/providers/catalog_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Category _category(String id, {String? parentId}) =>
    Category(id: id, parentId: parentId, name: 'Cat $id', slug: 'cat-$id');

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository({this.categories = const [], this.error});

  final List<Category> categories;
  final Object? error;

  @override
  Future<List<Category>> getCategories() async {
    if (error != null) throw error!;
    return categories;
  }

  @override
  Future<List<Category>> getRootCategories() async {
    if (error != null) throw error!;
    return categories.where((c) => c.isRoot).toList();
  }

  @override
  Future<List<Category>> getSubcategories(String parentId) async =>
      categories.where((c) => c.parentId == parentId).toList();

  @override
  Future<Category?> getCategoryById(String id) async => null;

  @override
  Future<List<String>> descendantCategoryIds(String rootId) async => [rootId];
}

ProviderContainer _container(CategoryRepository repo) {
  final container = ProviderContainer(
    overrides: [categoryRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load sets success with categories', () async {
    final container = _container(
      _FakeCategoryRepository(
        categories: [
          _category('root'),
          _category('child', parentId: 'root'),
        ],
      ),
    );

    await container.read(categoriesProvider.notifier).load();

    final state = container.read(categoriesProvider);
    expect(state.status, CatalogViewStatus.success);
    expect(state.data, hasLength(2));
  });

  test('loadRoots returns only root categories', () async {
    final container = _container(
      _FakeCategoryRepository(
        categories: [
          _category('root'),
          _category('child', parentId: 'root'),
        ],
      ),
    );

    await container.read(categoriesProvider.notifier).loadRoots();

    final state = container.read(categoriesProvider);
    expect(state.status, CatalogViewStatus.success);
    expect(state.data, hasLength(1));
    expect(state.data!.single.id, 'root');
  });

  test('load maps Failure to failure state', () async {
    final container = _container(
      _FakeCategoryRepository(error: const Failure(message: 'offline')),
    );

    await container.read(categoriesProvider.notifier).load();

    final state = container.read(categoriesProvider);
    expect(state.status, CatalogViewStatus.failure);
    expect(state.message, 'offline');
  });
}
