import 'package:aurivo/features/categories/domain/repositories/category_repository.dart';
import 'package:aurivo/features/categories/providers/category_providers.dart';
import 'package:aurivo/features/explore/presentation/explore_page.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_sort.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the small-screen product-card overflow (PriceWidget on narrow cells).
/// Uses realistic large PKR pricing that overflowed before the FittedBox fix.

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this.products);
  final List<Product> products;
  @override
  Future<List<Product>> getProducts({
    int limit = 20,
    int offset = 0,
    String? brandId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    String? material,
    ProductSort sort = ProductSort.newest,
  }) async => products;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoCategoryRepository implements CategoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Realistic Pakistan-first jewellery price with a struck-through original.
Product _pricyProduct() => const Product(
  id: 'p1',
  sellerId: 'seller-1',
  title: 'Handcrafted Gold Diamond Ring',
  slug: 'handcrafted-gold-diamond-ring',
  jewelleryType: 'ring',
  basePrice: 129999,
  comparePrice: 159999,
  currency: 'PKR',
  ratingCount: 12,
  ratingAverage: 4.6,
);

Future<void> _pumpExplore(
  WidgetTester tester,
  double width, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(
          _FakeProductRepository([_pricyProduct(), _pricyProduct()]),
        ),
        categoryRepositoryProvider.overrideWithValue(_NoCategoryRepository()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: const ExplorePage(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final width in [320.0, 360.0, 375.0, 412.0]) {
    testWidgets('Explore renders without overflow at ${width}px', (
      tester,
    ) async {
      await _pumpExplore(tester, width);
      // A RenderFlex overflow would be an uncaught exception.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no overflow at 375px with 1.3x text scale', (tester) async {
    await _pumpExplore(tester, 375, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the full current price stays visible at the narrowest width', (
    tester,
  ) async {
    await _pumpExplore(tester, 320);
    expect(tester.takeException(), isNull);
    // The complete current-price amount is rendered (scaled, never truncated).
    expect(find.text('PKR 129999.00'), findsWidgets);
    // The struck-through original price also remains present.
    expect(find.text('PKR 159999.00'), findsWidgets);
  });
}
