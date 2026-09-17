import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/cart/domain/entities/cart.dart';
import 'package:aurivo/features/cart/domain/entities/cart_view.dart';
import 'package:aurivo/features/cart/domain/repositories/cart_repository.dart';
import 'package:aurivo/features/cart/providers/cart_providers.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_detail.dart';
import 'package:aurivo/features/products/domain/entities/product_variant.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/presentation/product_page.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:aurivo/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:aurivo/features/wishlist/providers/wishlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Session fixed to authenticated for the signed-in regression.
class _AuthedSession extends SessionNotifier {
  _AuthedSession()
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      ) {
    state = const SessionState(status: SessionStatus.authenticated);
  }
}

/// Records every add attempt so a guest guard can be proven to write nothing.
class _CountingCartRepository implements CartRepository {
  _CountingCartRepository({this.fail = false});
  final bool fail;
  final List<({String variantId, int quantity})> addCalls = [];

  @override
  Future<CartView> addItem({
    required String productVariantId,
    int quantity = 1,
  }) async {
    addCalls.add((variantId: productVariantId, quantity: quantity));
    if (fail) throw const Failure(message: 'cart write failed');
    return const CartView(cart: Cart(id: 'c1'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DetailRepository implements ProductRepository {
  _DetailRepository(this.detail);
  final ProductDetail detail;

  @override
  Future<ProductDetail?> getProductDetail(String id) async => detail;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyWishlistRepository implements WishlistRepository {
  @override
  Future<Set<String>> getWishlistedProductIds() async => <String>{};

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
    currency: 'PKR',
  ),
  variants: [
    ProductVariant(id: 'v1', productId: 'p1', price: 1000, currency: 'PKR'),
  ],
);

Widget _app({
  required List<Override> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ProductPage(productId: 'p1'),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpLoaded(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(); // postFrame load
  await tester.pump(); // detail resolves
}

void main() {
  testWidgets('guest tap routes to login without any cart write', (
    tester,
  ) async {
    final cart = _CountingCartRepository();
    await _pumpLoaded(
      tester,
      _app(
        overrides: [
          productRepositoryProvider.overrideWithValue(
            _DetailRepository(_detail()),
          ),
          cartRepositoryProvider.overrideWithValue(cart),
          // No session override -> unauthenticated in tests.
        ],
      ),
    );

    expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_shopping_cart));
    await tester.pump(); // snackbar + navigation
    await tester.pump(const Duration(milliseconds: 350));

    // Zero backend/cart mutation.
    expect(cart.addCalls, isEmpty);
    // Sign-in-required feedback, then Login.
    expect(find.text('Sign in to add items to your cart.'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('authenticated tap adds the variant exactly once', (tester) async {
    final cart = _CountingCartRepository();
    await _pumpLoaded(
      tester,
      _app(
        overrides: [
          productRepositoryProvider.overrideWithValue(
            _DetailRepository(_detail()),
          ),
          cartRepositoryProvider.overrideWithValue(cart),
          wishlistRepositoryProvider.overrideWithValue(
            _EmptyWishlistRepository(),
          ),
          sessionProvider.overrideWith((ref) => _AuthedSession()),
        ],
      ),
    );

    await tester.tap(find.byIcon(Icons.add_shopping_cart));
    await tester.pump();
    await tester.pump();

    // Exactly one write, correct variant, default quantity preserved.
    expect(cart.addCalls, hasLength(1));
    expect(cart.addCalls.single.variantId, 'v1');
    expect(cart.addCalls.single.quantity, 1);
    // Success feedback, no login redirect.
    expect(find.text('Added to cart'), findsOneWidget);
    expect(find.text('LOGIN'), findsNothing);
  });

  testWidgets('authenticated cart failure shows feedback, no login redirect', (
    tester,
  ) async {
    final cart = _CountingCartRepository(fail: true);
    await _pumpLoaded(
      tester,
      _app(
        overrides: [
          productRepositoryProvider.overrideWithValue(
            _DetailRepository(_detail()),
          ),
          cartRepositoryProvider.overrideWithValue(cart),
          wishlistRepositoryProvider.overrideWithValue(
            _EmptyWishlistRepository(),
          ),
          sessionProvider.overrideWith((ref) => _AuthedSession()),
        ],
      ),
    );

    await tester.tap(find.byIcon(Icons.add_shopping_cart));
    await tester.pump();
    await tester.pump();

    expect(cart.addCalls, hasLength(1)); // the write was attempted
    expect(find.byType(SnackBar), findsOneWidget); // failure feedback shown
    expect(find.text('Added to cart'), findsNothing);
    expect(find.text('LOGIN'), findsNothing);
  });
}
