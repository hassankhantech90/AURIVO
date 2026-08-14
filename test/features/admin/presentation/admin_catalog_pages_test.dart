import 'package:aurivo/features/admin/domain/repositories/admin_catalog_repository.dart';
import 'package:aurivo/features/admin/presentation/admin_brands_page.dart';
import 'package:aurivo/features/admin/presentation/admin_categories_page.dart';
import 'package:aurivo/features/admin/providers/admin_catalog_providers.dart';
import 'package:aurivo/features/categories/domain/entities/category.dart';
import 'package:aurivo/features/products/domain/entities/brand.dart';
import 'package:aurivo/shared/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements AdminCatalogRepository {
  List<Category> categories = [
    const Category(id: 'c1', name: 'Rings', slug: 'rings'),
    const Category(id: 'c2', name: 'Necklaces', slug: 'necklaces', isActive: false),
  ];
  List<Brand> brands = [const Brand(id: 'b1', name: 'Aurum', slug: 'aurum')];
  int createdCategories = 0;

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
    createdCategories++;
    categories = [...categories, Category(id: 'c3', name: name, slug: slug)];
    return categories.last;
  }

  @override
  Future<List<Brand>> listBrands() async => brands;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(AdminCatalogRepository repo, Widget page) => ProviderScope(
  overrides: [adminCatalogRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(home: page),
);

void main() {
  testWidgets('categories page lists items with an inactive badge', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_FakeRepo(), const AdminCategoriesPage()));
    await tester.pumpAndSettle();
    expect(find.text('Rings'), findsOneWidget);
    expect(find.text('Necklaces'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget); // c2 is inactive
  });

  testWidgets('new-category form creates and refreshes', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo, const AdminCategoriesPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Bracelets');
    await tester.tap(find.widgetWithText(LoadingButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.createdCategories, 1);
    expect(find.text('Bracelets'), findsOneWidget); // list refreshed
  });

  testWidgets('brands page lists brands', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(), const AdminBrandsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Aurum'), findsOneWidget);
    expect(find.textContaining('/aurum'), findsOneWidget);
  });
}
