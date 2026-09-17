import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/wishlist/domain/entities/wishlist_item.dart';
import 'package:aurivo/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:aurivo/features/wishlist/presentation/widgets/wishlist_product_card.dart';
import 'package:aurivo/features/wishlist/providers/wishlist_providers.dart';
import 'package:aurivo/shared/widgets/common/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Session notifier fixed to authenticated for tests.
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

class _FakeWishlistRepository implements WishlistRepository {
  _FakeWishlistRepository({Set<String>? ids}) : _ids = ids ?? <String>{};
  final Set<String> _ids;
  int addCalls = 0;
  int removeCalls = 0;

  @override
  Future<Set<String>> getWishlistedProductIds() async => {..._ids};

  @override
  Future<List<WishlistItem>> getWishlist() async => _ids
      .map((id) => WishlistItem(id: id, profileId: 'p', productId: id))
      .toList();

  @override
  Future<bool> isWishlisted(String productId) async => _ids.contains(productId);

  @override
  Future<WishlistItem> add(String productId) async {
    addCalls++;
    _ids.add(productId);
    return WishlistItem(id: productId, profileId: 'p', productId: productId);
  }

  @override
  Future<void> remove(String productId) async {
    removeCalls++;
    _ids.remove(productId);
  }
}

Product _product({String? primaryImageUrl}) => Product(
  id: 'p1',
  sellerId: 'seller-1',
  title: 'Gold Ring',
  slug: 'gold-ring',
  jewelleryType: 'ring',
  basePrice: 1000,
  primaryImageUrl: primaryImageUrl,
);

Widget _app({
  required List<Override> overrides,
  Product? product,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: WishlistProductCard(product: product ?? _product()),
            ),
          ),
        ),
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

void main() {
  testWidgets('authenticated tap adds to the wishlist', (tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeWishlistRepository();
    await tester.pumpWidget(
      _app(
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith((ref) => _AuthedSession()),
        ],
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(repo.addCalls, 1);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('renders the enriched primary image url', (tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(
            _FakeWishlistRepository(),
          ),
        ],
        product: _product(
          primaryImageUrl: 'https://cdn.test/product-images/p1/hero.jpg',
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<NetworkImageWidget>(
      find.byType(NetworkImageWidget),
    );
    expect(image.imageUrl, 'https://cdn.test/product-images/p1/hero.jpg');
  });

  testWidgets('guest tap routes to login without writing', (tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeWishlistRepository();
    await tester.pumpWidget(
      // No session override -> unauthenticated in tests.
      _app(overrides: [wishlistRepositoryProvider.overrideWithValue(repo)]),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(repo.addCalls, 0);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
