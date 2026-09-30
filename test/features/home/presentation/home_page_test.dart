import 'dart:async';

import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/core/theme/theme.dart';
import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/cart/domain/entities/cart.dart';
import 'package:aurivo/features/cart/domain/entities/cart_item.dart';
import 'package:aurivo/features/cart/domain/entities/cart_view.dart';
import 'package:aurivo/features/cart/domain/repositories/cart_repository.dart';
import 'package:aurivo/features/cart/providers/cart_providers.dart';
import 'package:aurivo/features/categories/domain/entities/category.dart';
import 'package:aurivo/features/categories/domain/repositories/category_repository.dart';
import 'package:aurivo/features/categories/providers/category_providers.dart';
import 'package:aurivo/features/chat/domain/entities/conversation.dart';
import 'package:aurivo/features/chat/domain/repositories/chat_repository.dart';
import 'package:aurivo/features/chat/providers/chat_providers.dart';
import 'package:aurivo/features/home/presentation/home_page.dart';
import 'package:aurivo/features/notifications/domain/entities/app_notification.dart';
import 'package:aurivo/features/notifications/domain/repositories/notification_repository.dart';
import 'package:aurivo/features/notifications/providers/notification_providers.dart';
import 'package:aurivo/features/products/domain/entities/catalog_filters.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_sort.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:aurivo/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:aurivo/features/wishlist/providers/wishlist_providers.dart';
import 'package:aurivo/shared/widgets/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

// --- Fakes (unused interface methods route through noSuchMethod) -------------

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository({this.categories = const [], this.error, this.hang});
  final List<Category> categories;
  final Object? error;
  final Completer<List<Category>>? hang;

  @override
  Future<List<Category>> getRootCategories() {
    if (hang != null) return hang!.future;
    if (error != null) return Future<List<Category>>.error(error!);
    return Future<List<Category>>.value(categories);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({this.products = const [], this.error, this.hang});
  final List<Product> products;
  final Object? error;
  final Completer<List<Product>>? hang;
  int getProductsCalls = 0;
  bool? lastFeatured;
  bool lastWholesaleOnly = false;

  @override
  Future<List<Product>> getProducts({
    int limit = 20,
    int offset = 0,
    String? brandId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    String? material,
    String? search,
    bool wholesaleOnly = false,
    ProductSort sort = ProductSort.newest,
    CatalogFilters filters = const CatalogFilters(),
  }) {
    getProductsCalls++;
    lastFeatured = featured;
    lastWholesaleOnly = wholesaleOnly;
    if (hang != null) return hang!.future;
    if (error != null) return Future<List<Product>>.error(error!);
    return Future<List<Product>>.value(products);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Spies that record whether the authenticated-only home data was requested.
class _SpyWishlistRepository implements WishlistRepository {
  int calls = 0;
  @override
  Future<Set<String>> getWishlistedProductIds() async {
    calls++;
    return <String>{};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyChatRepository implements ChatRepository {
  int calls = 0;
  @override
  Future<List<ConversationSummary>> getConversations() async {
    calls++;
    return <ConversationSummary>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyNotificationRepository implements NotificationRepository {
  int calls = 0;
  @override
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    calls++;
    return <AppNotification>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Cart notifier seeded to a fixed item count (no repository calls).
class _StubCartRepository implements CartRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubCartNotifier extends CartNotifier {
  _StubCartNotifier(int itemCount) : super(_StubCartRepository()) {
    state = itemCount <= 0
        ? const CartState(status: CartStatus.success)
        : CartState(
            status: CartStatus.success,
            cart: CartView(
              cart: const Cart(id: 'c1'),
              items: [
                CartItem(
                  id: 'i1',
                  cartId: 'c1',
                  productVariantId: 'v1',
                  quantity: itemCount,
                  unitPriceSnapshot: 1000,
                ),
              ],
            ),
          );
  }

  // The badge only reads state; never trigger a real load.
  @override
  Future<void> load() async {}
}

Override _cartCount(int count) =>
    cartProvider.overrideWith((ref) => _StubCartNotifier(count));

/// A real cart repository returning [items] lines, to exercise the genuine
/// cartProvider (with its auth-reset listener) rather than a stub.
class _CountCartRepository implements CartRepository {
  _CountCartRepository(this.items);
  final int items;

  @override
  Future<CartView> getCart() async => CartView(
    cart: const Cart(id: 'c1', profileId: 'p1'),
    items: List.generate(
      items,
      (i) => CartItem(
        id: 'i$i',
        cartId: 'c1',
        productVariantId: 'v$i',
        quantity: 1,
        unitPriceSnapshot: 1000,
      ),
    ),
  );

  @override
  void clearSessionCache() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Session whose state the test drives (starts at [initial]).
class _MutableSession extends SessionNotifier {
  _MutableSession([SessionState? initial])
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      ) {
    if (initial != null) state = initial;
  }
  void set(SessionState next) => state = next;
}

SessionState _authAs(String id) => SessionState(
  status: SessionStatus.authenticated,
  user: User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026).toIso8601String(),
  ),
);

/// Session fixed to authenticated (no override => unauthenticated/guest).
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

// --- Fixtures ----------------------------------------------------------------

Category _category(String name) =>
    Category(id: name.toLowerCase(), name: name, slug: name.toLowerCase());

Product _product(String id) => Product(
  id: id,
  sellerId: 'seller-1',
  title: 'Ring $id',
  slug: 'ring-$id',
  jewelleryType: 'ring',
  basePrice: 1000,
);

Widget _home({required List<Override> overrides, ThemeData? theme}) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
      GoRoute(
        path: AppRoutes.explore,
        builder: (_, s) => Scaffold(
          body: Text(
            'EXPLORE_${s.uri.queryParameters['category'] ?? 'none'}'
            '_${s.uri.queryParameters['material'] ?? 'none'}'
            '_${s.uri.queryParameters['q'] ?? 'none'}',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.product,
        builder: (_, s) =>
            Scaffold(body: Text('PRODUCT_${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: AppRoutes.messages,
        builder: (_, _) => const Scaffold(body: Text('MESSAGES')),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const Scaffold(body: Text('NOTIFICATIONS')),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const Scaffold(body: Text('SETTINGS')),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (_, _) => const Scaffold(body: Text('CART')),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router, theme: theme),
  );
}

List<Override> _catalog({
  _FakeCategoryRepository? categories,
  _FakeProductRepository? products,
}) => [
  categoryRepositoryProvider.overrideWithValue(
    categories ?? _FakeCategoryRepository(),
  ),
  productRepositoryProvider.overrideWithValue(
    products ?? _FakeProductRepository(),
  ),
];

/// Lets the post-frame _load() run and settle immediate futures.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(); // fire the post-frame _load()
  await tester.pump(); // apply resolved state
}

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('A. rendering', () {
    testWidgets('shows app bar, sections, content, and actions', (
      tester,
    ) async {
      _bigView(tester);
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            categories: _FakeCategoryRepository(
              categories: [_category('Rings')],
            ),
            products: _FakeProductRepository(products: [_product('p1')]),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('AURIVO'), findsOneWidget);
      expect(find.text('Shop by category'), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Rings'), findsOneWidget); // category card
      expect(find.text('Ring p1'), findsOneWidget); // featured product card
      expect(find.byTooltip('Cart'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      // Messages + Settings moved into the overflow menu.
      expect(find.byTooltip('More'), findsOneWidget);
    });
  });

  group('B. category section states', () {
    testWidgets('loading shows the indicator', (tester) async {
      _bigView(tester);
      final hang = Completer<List<Category>>();
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            categories: _FakeCategoryRepository(hang: hang),
            products: _FakeProductRepository(products: const []),
          ),
        ),
      );
      await _settle(tester);

      expect(find.byType(LoadingIndicator), findsOneWidget); // category only
      expect(find.text('No featured products yet'), findsOneWidget);
    });

    testWidgets('empty shows the empty text', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            categories: _FakeCategoryRepository(categories: const []),
            products: _FakeProductRepository(products: [_product('p1')]),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('No categories yet.'), findsOneWidget);
    });

    testWidgets('failure shows the error text and no Retry', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            categories: _FakeCategoryRepository(error: Exception('cat down')),
            products: _FakeProductRepository(products: [_product('p1')]),
          ),
        ),
      );
      await _settle(tester);

      expect(find.textContaining('cat down'), findsOneWidget);
      // The category section intentionally has no Retry (only Featured does).
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('success renders category cards', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            categories: _FakeCategoryRepository(
              categories: [_category('Rings'), _category('Necklaces')],
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Rings'), findsOneWidget);
      expect(find.text('Necklaces'), findsOneWidget);
    });
  });

  group('C. featured section states', () {
    testWidgets('loading shows the indicator', (tester) async {
      _bigView(tester);
      final hang = Completer<List<Product>>();
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            categories: _FakeCategoryRepository(categories: const []),
            products: _FakeProductRepository(hang: hang),
          ),
        ),
      );
      await _settle(tester);

      expect(find.byType(LoadingIndicator), findsOneWidget); // featured only
      expect(find.text('No categories yet.'), findsOneWidget);
    });

    testWidgets('empty shows the empty state', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            products: _FakeProductRepository(products: const []),
            categories: _FakeCategoryRepository(categories: [_category('R')]),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('No featured products yet'), findsOneWidget);
    });

    testWidgets('failure shows an error with a Retry that reloads', (
      tester,
    ) async {
      _bigView(tester);
      final products = _FakeProductRepository(error: Exception('prod down'));
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            categories: _FakeCategoryRepository(categories: const []),
            products: products,
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      final callsBefore = products.getProductsCalls;

      await tester.tap(find.text('Retry'));
      await _settle(tester);

      // Retry re-requested the featured products exactly once more.
      expect(products.getProductsCalls, callsBefore + 1);
    });

    testWidgets('success renders product cards', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            products: _FakeProductRepository(
              products: [_product('p1'), _product('p2')],
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Ring p1'), findsOneWidget);
      expect(find.text('Ring p2'), findsOneWidget);
    });
  });

  group('D. app-bar badges', () {
    testWidgets('hidden when both counts are zero', (tester) async {
      await tester.pumpWidget(
        _home(
          overrides: [
            ..._catalog(),
            unreadChatCountProvider.overrideWithValue(0),
            unreadNotificationsCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await _settle(tester);

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('show the counts when positive', (tester) async {
      await tester.pumpWidget(
        _home(
          overrides: [
            ..._catalog(),
            _cartCount(5),
            unreadNotificationsCountProvider.overrideWithValue(12),
          ],
        ),
      );
      await _settle(tester);

      // Header carries two count badges: the cart and the notifications bell.
      expect(find.byType(Badge), findsNWidgets(2));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('cap counts over 99 at "99+"', (tester) async {
      await tester.pumpWidget(
        _home(
          overrides: [
            ..._catalog(),
            _cartCount(0),
            unreadNotificationsCountProvider.overrideWithValue(150),
          ],
        ),
      );
      await _settle(tester);

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('E. guest vs authenticated load gating', () {
    testWidgets('guest loads catalog but not personal data', (tester) async {
      final wishlist = _SpyWishlistRepository();
      final chat = _SpyChatRepository();
      final notifications = _SpyNotificationRepository();
      final products = _FakeProductRepository(products: const []);
      final categories = _FakeCategoryRepository(categories: const []);

      await tester.pumpWidget(
        _home(
          // No session override -> guest.
          overrides: [
            categoryRepositoryProvider.overrideWithValue(categories),
            productRepositoryProvider.overrideWithValue(products),
            wishlistRepositoryProvider.overrideWithValue(wishlist),
            chatRepositoryProvider.overrideWithValue(chat),
            notificationRepositoryProvider.overrideWithValue(notifications),
          ],
        ),
      );
      await _settle(tester);

      // Catalog loaded for everyone.
      expect(products.getProductsCalls, 1);
      // Personal data NOT requested for a guest.
      expect(wishlist.calls, 0);
      expect(chat.calls, 0);
      expect(notifications.calls, 0);
    });

    testWidgets('authenticated loads catalog and personal data', (
      tester,
    ) async {
      final wishlist = _SpyWishlistRepository();
      final chat = _SpyChatRepository();
      final notifications = _SpyNotificationRepository();
      final products = _FakeProductRepository(products: const []);
      final categories = _FakeCategoryRepository(categories: const []);

      await tester.pumpWidget(
        _home(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(categories),
            productRepositoryProvider.overrideWithValue(products),
            wishlistRepositoryProvider.overrideWithValue(wishlist),
            chatRepositoryProvider.overrideWithValue(chat),
            notificationRepositoryProvider.overrideWithValue(notifications),
            sessionProvider.overrideWith((ref) => _AuthedSession()),
          ],
        ),
      );
      await _settle(tester);

      expect(products.getProductsCalls, 1);
      expect(wishlist.calls, 1);
      expect(chat.calls, 1);
      expect(notifications.calls, 1);
    });
  });

  group('F. navigation', () {
    Future<void> pumpHome(WidgetTester tester) async {
      _bigView(tester);
      await tester.pumpWidget(
        _home(
          overrides: _catalog(
            categories: _FakeCategoryRepository(
              categories: [_category('Rings')],
            ),
            products: _FakeProductRepository(products: [_product('p1')]),
          ),
        ),
      );
      await _settle(tester);
    }

    Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('category card -> /explore with the exact category id', (
      tester,
    ) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.text('Rings'));
      // The tapped category's id ('rings') is transmitted as ?category=.
      expect(find.text('EXPLORE_rings_none_none'), findsOneWidget);
    });

    testWidgets('metal tab -> /explore with the metal as ?material=', (
      tester,
    ) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.text('Gold'));
      expect(find.text('EXPLORE_none_Gold_none'), findsOneWidget);
    });

    testWidgets('search submit -> /explore with the query as ?q=', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.enterText(find.byType(SearchBar), 'jhumka');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('EXPLORE_none_none_jhumka'), findsOneWidget);
    });

    testWidgets('blank search submit does not navigate', (tester) async {
      await pumpHome(tester);
      await tester.enterText(find.byType(SearchBar), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Still on Home; no Explore stub was pushed.
      expect(find.textContaining('EXPLORE_'), findsNothing);
    });

    testWidgets('product card -> /product/:id with the product id', (
      tester,
    ) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.text('Ring p1'));
      expect(find.text('PRODUCT_p1'), findsOneWidget);
    });

    testWidgets('Messages action (overflow) -> /messages', (tester) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.byTooltip('More'));
      await tapAndSettle(tester, find.text('Messages'));
      expect(find.text('MESSAGES'), findsOneWidget);
    });

    testWidgets('Notifications action -> /notifications', (tester) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.byTooltip('Notifications'));
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
    });

    testWidgets('Settings action (overflow) -> /settings', (tester) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.byTooltip('More'));
      await tapAndSettle(tester, find.text('Settings'));
      expect(find.text('SETTINGS'), findsOneWidget);
    });
  });

  group('G. cart action', () {
    List<Override> base(int cartCount) => [
      ..._catalog(
        categories: _FakeCategoryRepository(categories: [_category('Rings')]),
        products: _FakeProductRepository(products: [_product('p1')]),
      ),
      _cartCount(cartCount),
      unreadChatCountProvider.overrideWithValue(0),
      unreadNotificationsCountProvider.overrideWithValue(0),
    ];

    testWidgets('shows a Cart action that navigates to /cart', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_home(overrides: base(0)));
      await _settle(tester);

      expect(find.byTooltip('Cart'), findsOneWidget);
      // Notifications icon + the overflow menu remain present.
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);

      await tester.tap(find.byTooltip('Cart'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('CART'), findsOneWidget);
    });

    testWidgets('zero cart items shows no cart badge', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_home(overrides: base(0)));
      await _settle(tester);

      expect(find.byTooltip('Cart'), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('positive cart count shows the correct badge', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_home(overrides: base(3)));
      await _settle(tester);

      // Only the cart badge (chat/notifications overridden to 0).
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('no overflow at 320px with all actions and badges', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _home(
          overrides: [
            ..._catalog(
              categories: _FakeCategoryRepository(
                categories: [_category('Rings')],
              ),
              products: _FakeProductRepository(products: [_product('p1')]),
            ),
            _cartCount(3),
            unreadChatCountProvider.overrideWithValue(8),
            unreadNotificationsCountProvider.overrideWithValue(2),
          ],
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Cart'), findsOneWidget);
    });
  });

  group('G2. cart badge auth reset', () {
    testWidgets('badge clears when the auth identity changes', (tester) async {
      _bigView(tester);
      final session = _MutableSession(_authAs('user-A'));
      await tester.pumpWidget(
        _home(
          overrides: [
            ..._catalog(),
            cartRepositoryProvider.overrideWithValue(_CountCartRepository(3)),
            sessionProvider.overrideWith((ref) => session),
            unreadChatCountProvider.overrideWithValue(0),
            unreadNotificationsCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await _settle(tester);

      // Seed user A's cart, then confirm the badge reflects it.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      await container.read(cartProvider.notifier).load();
      await tester.pump();
      expect(find.text('3'), findsOneWidget);

      // Identity change A -> guest: the previous count must disappear.
      session.set(const SessionState(status: SessionStatus.unauthenticated));
      await tester.pump();

      expect(find.byType(Badge), findsNothing);
    });
  });

  group('H. dark mode', () {
    testWidgets('renders app bar and sections readably in dark mode', (
      tester,
    ) async {
      _bigView(tester);
      await tester.pumpWidget(
        _home(
          theme: AppTheme.dark,
          overrides: _catalog(
            categories: _FakeCategoryRepository(
              categories: [_category('Rings')],
            ),
            products: _FakeProductRepository(products: [_product('p1')]),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('AURIVO'), findsOneWidget);
      expect(find.text('Shop by category'), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
    });
  });

  group('I. retail/wholesale toggle', () {
    testWidgets('defaults to retail, loading featured products', (
      tester,
    ) async {
      _bigView(tester);
      final products = _FakeProductRepository(products: [_product('p1')]);
      await tester.pumpWidget(
        _home(overrides: _catalog(products: products)),
      );
      await _settle(tester);

      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Wholesale picks'), findsNothing);
      expect(products.lastFeatured, isTrue);
      expect(products.lastWholesaleOnly, isFalse);
    });

    testWidgets('switching to Wholesale reloads wholesale-only and relabels', (
      tester,
    ) async {
      _bigView(tester);
      final products = _FakeProductRepository(products: [_product('p1')]);
      await tester.pumpWidget(
        _home(overrides: _catalog(products: products)),
      );
      await _settle(tester);

      await tester.tap(find.text('Wholesale'));
      await _settle(tester);

      expect(find.text('Wholesale picks'), findsOneWidget);
      expect(products.lastWholesaleOnly, isTrue);
    });
  });
}
