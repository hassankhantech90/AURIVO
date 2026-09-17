import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_detail.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/presentation/product_page.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:aurivo/shared/widgets/common/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a single detail with a pre-resolved primary image URL; every other
/// repository call is unimplemented (the page only needs the detail here).
class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this.detail);
  final ProductDetail detail;

  @override
  Future<ProductDetail?> getProductDetail(String id) async => detail;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductDetail _detail() => const ProductDetail(
  product: Product(
    id: 'p1',
    sellerId: 's1',
    title: 'Gold Ring',
    slug: 'gold-ring',
    jewelleryType: 'ring',
    basePrice: 1000,
    primaryImageUrl: 'https://cdn.test/product-images/p1/hero.jpg',
  ),
);

void main() {
  testWidgets('detail hero renders the resolved primary image url', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(
            _FakeProductRepository(_detail()),
          ),
        ],
        child: const MaterialApp(home: ProductPage(productId: 'p1')),
      ),
    );
    // postFrame load -> loading -> success.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final image = tester.widget<NetworkImageWidget>(
      find.byType(NetworkImageWidget),
    );
    expect(image.imageUrl, 'https://cdn.test/product-images/p1/hero.jpg');
  });
}
