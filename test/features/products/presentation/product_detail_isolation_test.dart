import 'dart:async';

import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_detail.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/presentation/product_page.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:aurivo/shared/widgets/common/network_image_widget.dart';
import 'package:aurivo/shared/widgets/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves product A immediately and holds product B in a loading state until its
/// completer is fulfilled — proving B never shows A's detail while it loads.
class _AbRepository implements ProductRepository {
  _AbRepository({required this.aDetail, required this.bCompleter});

  final ProductDetail aDetail;
  final Completer<ProductDetail?> bCompleter;

  @override
  Future<ProductDetail?> getProductDetail(String id) {
    if (id == 'A') return Future<ProductDetail?>.value(aDetail);
    return bCompleter.future; // B stays loading until completed by the test.
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product _product(
  String id, {
  required String title,
  required double price,
  required String imageUrl,
}) => Product(
  id: id,
  sellerId: 'seller-1',
  title: title,
  slug: 'slug-$id',
  jewelleryType: 'ring',
  basePrice: price,
  currency: 'PKR',
  primaryImageUrl: imageUrl,
);

/// Swaps the mounted ProductPage under a single ProviderScope so page A is fully
/// removed from the tree when B mounts (as a route replacement would).
class _Switcher extends StatefulWidget {
  const _Switcher({super.key});
  @override
  State<_Switcher> createState() => _SwitcherState();
}

class _SwitcherState extends State<_Switcher> {
  String _id = 'A';
  void show(String id) => setState(() => _id = id);

  @override
  Widget build(BuildContext context) =>
      ProductPage(key: ValueKey(_id), productId: _id);
}

void main() {
  testWidgets('product B never shows product A detail (state isolation)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bCompleter = Completer<ProductDetail?>();
    final repo = _AbRepository(
      aDetail: ProductDetail(
        product: _product(
          'A',
          title: 'PRODUCT_A',
          price: 1111,
          imageUrl: 'https://cdn.test/product-images/A.jpg',
        ),
      ),
      bCompleter: bCompleter,
    );

    final switcherKey = GlobalKey<_SwitcherState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [productRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: _Switcher(key: switcherKey)),
      ),
    );
    // A loads and resolves.
    await tester.pump();
    await tester.pump();
    expect(find.text('PRODUCT_A'), findsWidgets);
    expect(find.text('PKR 1111.00'), findsOneWidget);

    // Navigate to B; its request is held open (loading).
    switcherKey.currentState!.show('B');
    await tester.pump(); // mount B page
    await tester.pump(); // postFrame load -> loading (held)

    // While B loads, none of A's content leaks through B's page.
    expect(find.text('PRODUCT_A'), findsNothing);
    expect(find.text('PKR 1111.00'), findsNothing);
    expect(find.byType(LoadingIndicator), findsWidgets);
    expect(find.byType(NetworkImageWidget), findsNothing);

    // Complete B.
    bCompleter.complete(
      ProductDetail(
        product: _product(
          'B',
          title: 'PRODUCT_B',
          price: 2222,
          imageUrl: 'https://cdn.test/product-images/B.jpg',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('PRODUCT_B'), findsWidgets);
    expect(find.text('PKR 2222.00'), findsOneWidget);
    expect(find.text('PRODUCT_A'), findsNothing);
    final hero = tester.widget<NetworkImageWidget>(
      find.byType(NetworkImageWidget),
    );
    expect(hero.imageUrl, 'https://cdn.test/product-images/B.jpg');
  });
}
