import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/home/presentation/widgets/home_hero_carousel.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Product _product(String id, {String? imageUrl}) => Product(
  id: id,
  sellerId: 'seller-1',
  title: 'Ring $id',
  slug: 'ring-$id',
  jewelleryType: 'ring',
  basePrice: 1000,
  primaryImageUrl: imageUrl,
);

Widget _host(List<Product> products) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            Scaffold(body: HomeHeroCarousel(products: products)),
      ),
      GoRoute(
        path: AppRoutes.product,
        builder: (_, s) => Scaffold(
          body: Text('PRODUCT_${s.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: AppRoutes.explore,
        builder: (_, _) => const Scaffold(body: Text('EXPLORE')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('renders a headline and page dots for product slides', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _product('a', imageUrl: 'https://img/a.jpg'),
        _product('b', imageUrl: 'https://img/b.jpg'),
      ]),
    );
    await tester.pump();

    expect(find.text('Crafted to be remembered'), findsOneWidget);
    // Two slides → the dots row renders two AnimatedContainers.
    expect(find.byType(AnimatedContainer), findsNWidgets(2));
  });

  testWidgets('tapping a product slide opens that product', (tester) async {
    await tester.pumpWidget(
      _host([_product('a', imageUrl: 'https://img/a.jpg')]),
    );
    await tester.pump();

    await tester.tap(find.text('Crafted to be remembered'));
    await tester.pumpAndSettle();

    expect(find.text('PRODUCT_a'), findsOneWidget);
  });

  testWidgets('falls back to a single branded slide with no images', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const []));
    await tester.pump();

    expect(find.text('Crafted to be remembered'), findsOneWidget);
    // A single slide shows no dots.
    expect(find.byType(AnimatedContainer), findsNothing);

    await tester.tap(find.text('Crafted to be remembered'));
    await tester.pumpAndSettle();

    expect(find.text('EXPLORE'), findsOneWidget);
  });
}
