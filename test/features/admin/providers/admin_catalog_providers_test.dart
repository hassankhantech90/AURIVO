import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/domain/repositories/admin_catalog_repository.dart';
import 'package:aurivo/features/admin/providers/admin_catalog_providers.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart'
    show AdminStatus;
import 'package:aurivo/features/categories/domain/entities/category.dart';
import 'package:aurivo/features/products/domain/entities/attribute.dart';
import 'package:aurivo/features/products/domain/entities/brand.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCatalogRepo implements AdminCatalogRepository {
  final List<String> log = [];
  List<Category> categories = [
    const Category(id: 'c1', name: 'Rings', slug: 'rings'),
  ];

  @override
  Future<List<Category>> listCategories() async => categories;

  @override
  Future<Category> createCategory({
    required String name,
    required String slug,
    String? parentId,
    String? description,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    log.add('create:$slug');
    categories = [...categories, Category(id: 'c2', name: name, slug: slug)];
    return categories.last;
  }

  @override
  Future<Category> updateCategory({
    required String id,
    String? name,
    String? slug,
    String? parentId,
    bool clearParent = false,
    String? description,
    int? sortOrder,
    bool? isActive,
  }) async {
    log.add('update:$id');
    return Category(id: id, name: name ?? 'x', slug: slug ?? 'x');
  }

  @override
  Future<void> deleteCategory(String id) async {
    log.add('delete:$id');
    categories = categories.where((c) => c.id != id).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingRepo extends _FakeCatalogRepo {
  @override
  Future<Category> createCategory({
    required String name,
    required String slug,
    String? parentId,
    String? description,
    int sortOrder = 0,
    bool isActive = true,
  }) async => throw const Failure(message: 'slug must be unique');
}

ProviderContainer _container(AdminCatalogRepository repo) {
  final container = ProviderContainer(
    overrides: [adminCatalogRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load then create reloads the list', () async {
    final repo = _FakeCatalogRepo();
    final container = _container(repo);
    final notifier = container.read(adminCategoriesProvider.notifier);
    await notifier.load();
    expect(container.read(adminCategoriesProvider).status, AdminStatus.success);

    final err = await notifier.save(
      name: 'Necklaces',
      slug: 'necklaces',
      sortOrder: 0,
      isActive: true,
    );
    expect(err, isNull);
    expect(repo.log, contains('create:necklaces'));
    expect(container.read(adminCategoriesProvider).data.map((c) => c.id),
        ['c1', 'c2']);
  });

  test('remove soft-deletes and reloads', () async {
    final repo = _FakeCatalogRepo();
    final container = _container(repo);
    final notifier = container.read(adminCategoriesProvider.notifier);
    await notifier.load();
    final err = await notifier.remove('c1');
    expect(err, isNull);
    expect(repo.log, contains('delete:c1'));
    expect(container.read(adminCategoriesProvider).data, isEmpty);
  });

  test('save returns the error message on failure', () async {
    final container = _container(_ThrowingRepo());
    final err = await container
        .read(adminCategoriesProvider.notifier)
        .save(name: 'X', slug: 'x', sortOrder: 0, isActive: true);
    expect(err, contains('unique'));
  });

  test('brands and attributes providers are wired', () async {
    final container = _container(_FakeCatalogRepo());
    // Smoke: they build without throwing.
    expect(container.read(adminBrandsProvider).data, isA<List<Brand>>());
    expect(
      container.read(adminAttributesProvider).data,
      isA<List<Attribute>>(),
    );
  });
}
