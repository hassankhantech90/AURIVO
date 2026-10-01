import 'package:aurivo/features/categories/domain/entities/category.dart';
import 'package:aurivo/features/products/domain/entities/brand.dart';
import 'package:aurivo/features/seller/domain/entities/product_draft.dart';
import 'package:aurivo/features/seller/domain/entities/seller_product.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_product_repository.dart';
import 'package:aurivo/features/seller/presentation/seller_dashboard_page.dart';
import 'package:aurivo/features/seller/providers/seller_product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

SellerProduct _product({
  String id = 'prod-1',
  String title = 'Emerald Ring',
  String status = ProductStatus.draft,
}) => SellerProduct(
  id: id,
  sellerId: 'sp-1',
  title: title,
  slug: 'emerald-ring',
  jewelleryType: 'ring',
  basePrice: 5000,
  status: status,
);

class _FakeRepo implements SellerProductRepository {
  _FakeRepo({this.sellerId = 'sp-1', this.products = const []});
  final String? sellerId;
  final List<SellerProduct> products;

  @override
  Future<String?> mySellerProfileId() async => sellerId;

  @override
  Future<List<SellerProduct>> getMyProducts({
    int limit = 100,
    int offset = 0,
  }) async => products;

  @override
  Future<SellerProductDetail> getProduct(String id) async =>
      SellerProductDetail(product: _product(id: id));

  @override
  Future<SellerProduct> createProduct(ProductDraft draft) async => _product();

  @override
  Future<SellerProduct> updateProduct(String id, ProductDraft draft) async =>
      _product(id: id);

  @override
  Future<SellerProduct> setPublished(String id, bool published) async =>
      _product(id: id);

  final List<(String, bool)> pauseCalls = [];

  @override
  Future<SellerProduct> setPaused(String id, bool paused) async {
    pauseCalls.add((id, paused));
    return _product(id: id);
  }

  @override
  Future<void> softDelete(String id) async {}

  @override
  Future<List<Brand>> getBrands() async => const [];

  @override
  Future<List<Category>> getCategories() async => const [];
}

Widget _wrap(SellerProductRepository repo) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SellerDashboardPage()),
    ],
  );
  return ProviderScope(
    overrides: [sellerProductRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('non-sellers see the no-store prompt', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(sellerId: null)));
    await tester.pumpAndSettle();
    expect(find.text('No seller store yet'), findsOneWidget);
    expect(find.text('New product'), findsNothing);
  });

  testWidgets('sellers see their product list with status', (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeRepo(products: [_product(title: 'Emerald Ring')])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Emerald Ring'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('New product'), findsOneWidget);
  });

  testWidgets('a published product can be paused from its menu', (
    tester,
  ) async {
    final repo = _FakeRepo(
      products: [_product(status: ProductStatus.approved)],
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first); // product menu (body precedes the app bar)
    await tester.pumpAndSettle();
    expect(find.text('Pause listing'), findsOneWidget);
    expect(find.text('Unpublish'), findsOneWidget);
    expect(find.text('Submit for review'), findsNothing);

    await tester.tap(find.text('Pause listing'));
    await tester.pumpAndSettle();
    expect(repo.pauseCalls, [('prod-1', true)]);
  });

  testWidgets('a paused product shows Paused and can be resumed', (
    tester,
  ) async {
    final repo = _FakeRepo(products: [_product(status: ProductStatus.paused)]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).first); // product menu (body precedes the app bar)
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume listing'));
    await tester.pumpAndSettle();
    expect(repo.pauseCalls, [('prod-1', false)]);
  });

  testWidgets('sellers with no products see the empty state', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(products: const [])));
    await tester.pumpAndSettle();
    expect(find.text('No products yet'), findsOneWidget);
  });
}
