import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:aurivo/features/wishlist/domain/entities/wishlist_item.dart';
import 'package:aurivo/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:aurivo/features/wishlist/presentation/widgets/wishlist_product_card.dart';
import 'package:aurivo/features/wishlist/presentation/wishlist_page.dart';
import 'package:aurivo/features/wishlist/providers/wishlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    _ids.add(productId);
    return WishlistItem(id: productId, profileId: 'p', productId: productId);
  }

  @override
  Future<void> remove(String productId) async {
    removeCalls++;
    _ids.remove(productId);
  }
}

class _FakeProductRepository implements ProductRepository {
  @override
  Future<List<Product>> getProductsByIds(List<String> ids) async =>
      ids.map(_product).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product _product(String id) => Product(
  id: id,
  sellerId: 'seller-1',
  title: 'Ring $id',
  slug: 'ring-$id',
  jewelleryType: 'ring',
  basePrice: 1000,
);

Widget _wrap(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(home: WishlistPage()),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('guests are prompted to sign in', (tester) async {
    // Default (unauthenticated) session in tests.
    await tester.pumpWidget(
      _wrap([
        wishlistRepositoryProvider.overrideWithValue(_FakeWishlistRepository()),
      ]),
    );
    await _settle(tester);
    expect(find.text('Sign in to view your wishlist'), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing is saved', (tester) async {
    await tester.pumpWidget(
      _wrap([
        wishlistRepositoryProvider.overrideWithValue(_FakeWishlistRepository()),
        productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
        sessionProvider.overrideWith((ref) => _AuthedSession()),
      ]),
    );
    await _settle(tester);
    expect(find.text('No saved items yet'), findsOneWidget);
  });

  testWidgets('renders saved products and removes on heart tap', (tester) async {
    _bigView(tester);
    final repo = _FakeWishlistRepository(ids: {'p1', 'p2'});
    await tester.pumpWidget(
      _wrap([
        wishlistRepositoryProvider.overrideWithValue(repo),
        productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
        sessionProvider.overrideWith((ref) => _AuthedSession()),
      ]),
    );
    await _settle(tester);

    expect(find.byType(WishlistProductCard), findsNWidgets(2));
    expect(find.byIcon(Icons.favorite), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.favorite).first);
    await _settle(tester);

    expect(repo.removeCalls, 1);
    expect(find.byType(WishlistProductCard), findsOneWidget);
  });
}
