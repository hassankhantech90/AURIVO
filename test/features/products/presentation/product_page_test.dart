import 'dart:async';

import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/products/domain/entities/price_tier.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/entities/product_detail.dart';
import 'package:aurivo/features/products/domain/entities/product_variant.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/presentation/product_page.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/reviews/presentation/widgets/product_reviews_section.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart';
import 'package:aurivo/features/wishlist/domain/entities/wishlist_item.dart';
import 'package:aurivo/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:aurivo/features/wishlist/providers/wishlist_providers.dart';
import 'package:aurivo/shared/widgets/common/network_image_widget.dart';
import 'package:aurivo/shared/widgets/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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

/// Configurable product detail source: immediate detail, held loading, null
/// (not found), or fail-N-times-then-succeed (retry).
class _DetailRepository implements ProductRepository {
  _DetailRepository({
    this.detail,
    this.completer,
    this.failTimes = 0,
    this.returnNull = false,
    this.tiers = const [],
  });

  final ProductDetail? detail;
  final Completer<ProductDetail?>? completer;
  int failTimes;
  final bool returnNull;
  final List<PriceTier> tiers;
  int calls = 0;

  @override
  Future<List<PriceTier>> getProductPriceTiers(String id) async => tiers;

  @override
  Future<ProductDetail?> getProductDetail(String id) {
    calls++;
    if (completer != null) return completer!.future;
    if (failTimes > 0) {
      failTimes--;
      return Future<ProductDetail?>.error(const Failure(message: 'load failed'));
    }
    if (returnNull) return Future<ProductDetail?>.value(null);
    return Future<ProductDetail?>.value(detail);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingWishlistRepository implements WishlistRepository {
  final List<String> addCalls = [];

  @override
  Future<Set<String>> getWishlistedProductIds() async => <String>{};

  @override
  Future<bool> isWishlisted(String productId) async => false;

  @override
  Future<WishlistItem> add(String productId) async {
    addCalls.add(productId);
    return WishlistItem(id: productId, profileId: 'p', productId: productId);
  }

  @override
  Future<void> remove(String productId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Product _richProduct() => const Product(
  id: 'p1',
  sellerId: 's1',
  title:
      'Handcrafted 22k Gold Diamond Solitaire Engagement Ring — Limited Heritage Edition',
  slug: 'ring',
  jewelleryType: 'ring',
  material: 'Gold',
  purity: '22k',
  description:
      'An exquisite handcrafted solitaire set in certified 22k gold with a '
      'brilliant-cut diamond centre stone, finished by master artisans over '
      'many weeks for a truly heirloom-grade piece meant to last generations.',
  basePrice: 129999,
  comparePrice: 159999,
  currency: 'PKR',
  ratingAverage: 4.6,
  ratingCount: 12,
  primaryImageUrl: 'https://cdn.test/product-images/p1/hero.jpg',
);

ProductDetail _richDetail() => ProductDetail(
  product: _richProduct(),
  variants: const [
    ProductVariant(
      id: 'v1',
      productId: 'p1',
      price: 129999,
      comparePrice: 159999,
      currency: 'PKR',
      weightGrams: 5.5,
    ),
    ProductVariant(
      id: 'v2',
      productId: 'p1',
      price: 149999,
      currency: 'PKR',
      weightGrams: 7.25,
    ),
  ],
);

SellerProfile _seller() => const SellerProfile(
  id: 's1',
  profileId: 'pr1',
  storeName: 'Gold House Jewellers of Old Anarkali Bazaar',
  slug: 'gold-house',
);

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _app({
  required List<Override> overrides,
  ThemeData? theme,
  double textScale = 1.0,
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
      GoRoute(
        path: '/seller/:slug',
        builder: (_, s) =>
            Scaffold(body: Text('STORE ${s.pathParameters['slug']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: theme,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget app, {
  Size size = const Size(1000, 2200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(); // postFrame load
  await tester.pump(); // detail resolves
}

List<Override> _guestOverrides(ProductRepository repo, {bool withSeller = false}) {
  return [
    productRepositoryProvider.overrideWithValue(repo),
    if (withSeller)
      sellerByIdProvider.overrideWith((ref, id) async => _seller()),
  ];
}

void main() {
  group('loading state', () {
    testWidgets('shows the loader and no stale content while pending', (
      tester,
    ) async {
      final completer = Completer<ProductDetail?>();
      await _pump(
        tester,
        _app(overrides: _guestOverrides(_DetailRepository(completer: completer))),
      );

      expect(find.byType(LoadingIndicator), findsWidgets);
      // No product content and no usable actions before data arrives.
      expect(find.textContaining('Handcrafted'), findsNothing);
      expect(find.byIcon(Icons.add_shopping_cart), findsNothing);
      expect(find.text('Request a Quote'), findsNothing);

      completer.complete(_richDetail()); // avoid a pending future
      await tester.pump();
    });
  });

  group('wholesale pricing', () {
    testWidgets('shows MOQ and tiered price breaks when present', (
      tester,
    ) async {
      final detail = ProductDetail(
        product: _richProduct().copyWith(minOrderQuantity: 10),
        variants: _richDetail().variants,
      );
      await _pump(
        tester,
        _app(
          overrides: _guestOverrides(
            _DetailRepository(
              detail: detail,
              tiers: const [
                PriceTier(
                  id: 't1',
                  productId: 'p1',
                  minQuantity: 10,
                  unitPrice: 120000,
                ),
                PriceTier(
                  id: 't2',
                  productId: 'p1',
                  minQuantity: 50,
                  unitPrice: 110000,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(); // tiers future resolves

      expect(find.text('Wholesale'), findsOneWidget);
      expect(find.text('Minimum order'), findsOneWidget);
      expect(find.text('10 pieces'), findsOneWidget);
      expect(find.text('10+ pieces'), findsOneWidget);
      expect(find.text('PKR 120,000 each'), findsOneWidget);
      expect(find.text('50+ pieces'), findsOneWidget);
      expect(find.text('PKR 110,000 each'), findsOneWidget);
    });

    testWidgets('hides the wholesale block with no MOQ and no tiers', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(overrides: _guestOverrides(_DetailRepository(detail: _richDetail()))),
      );
      await tester.pump();

      expect(find.text('Wholesale'), findsNothing);
    });
  });

  group('success content', () {
    testWidgets('renders the core product detail', (tester) async {
      await _pump(
        tester,
        _app(
          overrides: _guestOverrides(
            _DetailRepository(detail: _richDetail()),
            withSeller: true,
          ),
        ),
      );

      // Title (app bar + body), image, pricing, rating.
      expect(find.textContaining('Handcrafted 22k Gold'), findsWidgets);
      final hero = tester.widget<NetworkImageWidget>(
        find.byType(NetworkImageWidget),
      );
      expect(hero.imageUrl, 'https://cdn.test/product-images/p1/hero.jpg');
      expect(find.text('PKR 129,999'), findsWidgets);
      expect(find.text('PKR 159,999'), findsWidgets); // compare price
      expect(find.text('4.6'), findsOneWidget); // rating summary

      // Specifications, description, seller, reviews.
      expect(find.text('Ring'), findsOneWidget); // Type spec row
      expect(find.text('Gold'), findsOneWidget); // Metal spec row
      expect(find.text('22K'), findsOneWidget); // Purity spec row (uppercased)
      expect(find.text('Description'), findsOneWidget);
      expect(find.textContaining('exquisite handcrafted'), findsOneWidget);
      expect(find.textContaining('Sold by Gold House'), findsOneWidget);
      expect(find.text('Request a Quote'), findsOneWidget);
      final reviews = tester.widget<ProductReviewsSection>(
        find.byType(ProductReviewsSection),
      );
      expect(reviews.productId, 'p1');

      // Variants: two rows, weights, and one add control each.
      expect(find.text('Options'), findsOneWidget);
      expect(find.text('5.50 g'), findsOneWidget);
      expect(find.text('7.25 g'), findsOneWidget);
      expect(find.byIcon(Icons.add_shopping_cart), findsNWidgets(2));
    });

    testWidgets('normal price without compare shows no struck price', (
      tester,
    ) async {
      const noCompare = Product(
        id: 'p1',
        sellerId: 's1',
        title: 'Plain Ring',
        slug: 'plain',
        jewelleryType: 'ring',
        basePrice: 5000,
        currency: 'PKR',
      );
      await _pump(
        tester,
        _app(
          overrides: _guestOverrides(
            _DetailRepository(detail: const ProductDetail(product: noCompare)),
          ),
        ),
      );
      expect(find.text('PKR 5,000'), findsWidgets);
      // No compare/original amount rendered.
      expect(find.text('PKR 159,999'), findsNothing);
    });
  });

  group('optional content & images', () {
    testWidgets('missing description/tags and image do not crash', (
      tester,
    ) async {
      const bare = Product(
        id: 'p1',
        sellerId: 's1',
        title: 'Bare Product',
        slug: 'bare',
        jewelleryType: 'ring',
        basePrice: 1000,
        currency: 'PKR',
        // no description, material, purity, primaryImageUrl
      );
      await _pump(
        tester,
        _app(
          overrides: _guestOverrides(
            _DetailRepository(detail: const ProductDetail(product: bare)),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Description'), findsNothing); // no description section
      expect(find.text('Ring'), findsOneWidget); // Type spec row remains
      final hero = tester.widget<NetworkImageWidget>(
        find.byType(NetworkImageWidget),
      );
      expect(hero.imageUrl, ''); // safe placeholder path, no crash
    });
  });

  group('variants', () {
    testWidgets('single active variant renders one add control', (tester) async {
      final detail = ProductDetail(
        product: _richProduct(),
        variants: const [
          ProductVariant(
            id: 'v1',
            productId: 'p1',
            price: 1000,
            currency: 'PKR',
            weightGrams: 3.0,
          ),
        ],
      );
      await _pump(
        tester,
        _app(overrides: _guestOverrides(_DetailRepository(detail: detail))),
      );
      expect(find.text('3.00 g'), findsOneWidget);
      expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
    });

    testWidgets(
      'variant-less product shows no Options / add control (characterization)',
      (tester) async {
        await _pump(
          tester,
          _app(
            overrides: _guestOverrides(
              _DetailRepository(detail: ProductDetail(product: _richProduct())),
            ),
          ),
        );
        // Current behavior: no variants -> no Options block, no add-to-cart.
        expect(find.text('Options'), findsNothing);
        expect(find.byIcon(Icons.add_shopping_cart), findsNothing);
        // Rest of the page still renders (Request a Quote remains available).
        expect(find.text('Request a Quote'), findsOneWidget);
      },
    );
  });

  group('wishlist (app bar)', () {
    testWidgets('authenticated tap toggles the wishlist', (tester) async {
      final wishlist = _RecordingWishlistRepository();
      await _pump(
        tester,
        _app(
          overrides: [
            productRepositoryProvider.overrideWithValue(
              _DetailRepository(detail: _richDetail()),
            ),
            wishlistRepositoryProvider.overrideWithValue(wishlist),
            sessionProvider.overrideWith((ref) => _AuthedSession()),
          ],
        ),
      );

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      await tester.pump();

      expect(wishlist.addCalls, ['p1']);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('guest tap shows sign-in feedback and routes to login', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(overrides: _guestOverrides(_DetailRepository(detail: _richDetail()))),
      );

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.text('Sign in to save items to your wishlist.'),
        findsOneWidget,
      );
      expect(find.text('LOGIN'), findsOneWidget);
    });
  });

  group('seller navigation', () {
    testWidgets('tapping the store link navigates to the seller route', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(
          overrides: _guestOverrides(
            _DetailRepository(detail: _richDetail()),
            withSeller: true,
          ),
        ),
      );

      await tester.tap(find.textContaining('Sold by Gold House'));
      await tester.pump();
      await tester.pump();

      expect(find.text('STORE gold-house'), findsOneWidget);
    });
  });

  group('request a quote', () {
    testWidgets('guest is routed to login', (tester) async {
      await _pump(
        tester,
        _app(overrides: _guestOverrides(_DetailRepository(detail: _richDetail()))),
      );

      await tester.tap(find.text('Request a Quote'));
      await tester.pump();
      await tester.pump();

      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('authenticated opens the RFQ sheet with product context', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(
          overrides: [
            productRepositoryProvider.overrideWithValue(
              _DetailRepository(detail: _richDetail()),
            ),
            wishlistRepositoryProvider.overrideWithValue(
              _RecordingWishlistRepository(),
            ),
            sessionProvider.overrideWith((ref) => _AuthedSession()),
          ],
        ),
      );

      await tester.tap(find.text('Request a Quote'));
      await tester.pump(); // start the modal sheet animation
      await tester.pump(const Duration(milliseconds: 400)); // sheet settled

      // The RFQ modal sheet is shown (its send button is unique to the sheet).
      expect(find.text('Send request'), findsOneWidget);
    });
  });

  group('error & not-found', () {
    testWidgets('failure shows error UI; Retry reloads successfully', (
      tester,
    ) async {
      final repo = _DetailRepository(detail: _richDetail(), failTimes: 1);
      await _pump(tester, _app(overrides: _guestOverrides(repo)));

      // First load failed.
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Handcrafted'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Handcrafted 22k Gold'), findsWidgets);
      expect(repo.calls, 2);
    });

    testWidgets('missing product shows the unavailable message', (tester) async {
      await _pump(
        tester,
        _app(overrides: _guestOverrides(_DetailRepository(returnNull: true))),
      );
      expect(
        find.text('This product is no longer available.'),
        findsOneWidget,
      );
    });
  });

  group('theming & responsiveness', () {
    testWidgets('renders in dark theme without exception', (tester) async {
      await _pump(
        tester,
        _app(
          overrides: _guestOverrides(
            _DetailRepository(detail: _richDetail()),
            withSeller: true,
          ),
          theme: ThemeData(brightness: Brightness.dark),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Handcrafted 22k Gold'), findsWidgets);
      expect(find.text('Request a Quote'), findsOneWidget);
    });

    // Regression for the resolved _VariantRow overflow (was IMPORTANT). The
    // fixture keeps realistic six-digit PKR prices with BOTH a compare-price
    // variant (v1) and a single-price variant (v2). At every constrained
    // width/scale the row must NOT overflow, yet every price/weight/action must
    // stay in the tree (the FittedBox only scales the display; it never drops
    // content).
    for (final (label, width, scale) in const [
      ('320px / 1.0x', 320.0, 1.0),
      ('375px / 1.3x', 375.0, 1.3),
      ('320px / 1.3x', 320.0, 1.3),
    ]) {
      testWidgets('variant rows are layout-safe at $label', (tester) async {
        await _pump(
          tester,
          _app(
            overrides: _guestOverrides(
              _DetailRepository(detail: _richDetail()),
              withSeller: true,
            ),
            textScale: scale,
          ),
          size: Size(width, 2800),
        );

        // No RenderFlex overflow / layout exception.
        expect(tester.takeException(), isNull);

        // Compare-price variant (v1): both amounts remain present.
        expect(find.text('PKR 129,999'), findsWidgets);
        expect(find.text('PKR 159,999'), findsWidgets);
        // Single-price variant (v2): its current price remains present.
        expect(find.text('PKR 149,999'), findsWidgets);

        // Weights and Add-to-Cart actions remain present for both variants.
        expect(find.text('5.50 g'), findsOneWidget);
        expect(find.text('7.25 g'), findsOneWidget);
        expect(find.byIcon(Icons.add_shopping_cart), findsNWidgets(2));
      });
    }
  });

  group('route regression', () {
    testWidgets('/product/:id builds ProductPage with the path id', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AppRoutes.productPath('sku-42'),
        routes: [
          GoRoute(
            path: AppRoutes.product,
            builder: (context, state) =>
                ProductPage(productId: state.pathParameters['id'] ?? ''),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productRepositoryProvider.overrideWithValue(
              _DetailRepository(completer: Completer()),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      final page = tester.widget<ProductPage>(find.byType(ProductPage));
      expect(page.productId, 'sku-42');
    });
  });
}
