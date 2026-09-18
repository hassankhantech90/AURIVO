import 'dart:async';

import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/cart/domain/entities/cart.dart';
import 'package:aurivo/features/cart/domain/entities/cart_item.dart';
import 'package:aurivo/features/cart/domain/entities/cart_view.dart';
import 'package:aurivo/features/cart/domain/repositories/cart_repository.dart';
import 'package:aurivo/features/cart/providers/cart_providers.dart';
import 'package:aurivo/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:aurivo/features/checkout/presentation/checkout_page.dart';
import 'package:aurivo/features/checkout/providers/checkout_providers.dart';
import 'package:aurivo/features/profile/domain/entities/address.dart';
import 'package:aurivo/features/profile/domain/repositories/profile_repository.dart';
import 'package:aurivo/features/profile/providers/profile_providers.dart';
import 'package:aurivo/shared/design_system.dart' show LoadingButton;
import 'package:aurivo/shared/widgets/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// --- Fakes -------------------------------------------------------------------

class _FakeCheckoutRepository implements CheckoutRepository {
  _FakeCheckoutRepository({this.authenticated = true, this.error});
  final bool authenticated;
  final Object? error;
  int placeCalls = 0;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Future<String> placeOrder({
    required String cartId,
    required String addressId,
    String paymentMethod = 'cash_on_delivery',
    String? notes,
  }) async {
    placeCalls++;
    if (error != null) throw error!;
    return 'order-1';
  }
}

class _FakeCartRepository implements CartRepository {
  _FakeCartRepository({this.items = 2, this.hang});
  final int items;
  final Completer<CartView>? hang;

  CartView _view() => CartView(
    cart: const Cart(
      id: 'c1',
      profileId: 'p1',
      currency: 'PKR',
      grandTotal: 129999,
    ),
    items: List.generate(
      items,
      (i) => CartItem(
        id: 'i$i',
        cartId: 'c1',
        productVariantId: 'v$i',
        quantity: 1,
        unitPriceSnapshot: 1000,
        productTitle: 'Item $i',
      ),
    ),
  );

  @override
  Future<CartView> getCart() {
    if (hang != null) return hang!.future;
    return Future.value(_view());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.addresses = const []});
  final List<Address> addresses;

  @override
  Future<List<Address>> getAddresses() async => addresses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- Fixtures ----------------------------------------------------------------

Address _address({
  String id = 'addr-1',
  String name = 'Ali Khan',
  bool isDefault = false,
  String line1 = '123 Mall Road',
}) => Address(
  id: id,
  profileId: 'p1',
  addressType: 'shipping',
  recipientName: name,
  phone: '03001234567',
  addressLine1: line1,
  city: 'Lahore',
  province: 'Punjab',
  isDefault: isDefault,
);

Widget _app({
  required List<Override> overrides,
  ThemeData? theme,
  double textScale = 1.0,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.checkout,
    routes: [
      GoRoute(
        path: AppRoutes.checkout,
        builder: (_, _) => const CheckoutPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        builder: (_, _) => const Scaffold(body: Text('ADDRESSES')),
      ),
      GoRoute(
        path: AppRoutes.orderDetail,
        builder: (_, s) =>
            Scaffold(body: Text('ORDER_${s.pathParameters['id']}')),
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

List<Override> _overrides({
  _FakeCheckoutRepository? checkout,
  _FakeCartRepository? cart,
  _FakeProfileRepository? profile,
}) => [
  checkoutRepositoryProvider.overrideWithValue(
    checkout ?? _FakeCheckoutRepository(),
  ),
  cartRepositoryProvider.overrideWithValue(cart ?? _FakeCartRepository()),
  profileRepositoryProvider.overrideWithValue(
    profile ?? _FakeProfileRepository(),
  ),
];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(); // post-frame loads
  await tester.pump();
  await tester.pump();
}

void main() {
  group('A. loading', () {
    testWidgets('shows the loader while the cart is pending', (tester) async {
      final hang = Completer<CartView>();
      await tester.pumpWidget(
        _app(overrides: _overrides(cart: _FakeCartRepository(hang: hang))),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(LoadingIndicator), findsWidgets);
      expect(find.text('Place order'), findsNothing);
    });
  });

  group('B. empty cart', () {
    testWidgets('renders the empty state and no Place order CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(overrides: _overrides(cart: _FakeCartRepository(items: 0))),
      );
      await _settle(tester);

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Browse catalogue'), findsOneWidget);
      expect(find.text('Place order'), findsNothing);
    });
  });

  group('C. authenticated content', () {
    testWidgets('renders addresses, COD, notes, summary and CTA', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          overrides: _overrides(
            profile: _FakeProfileRepository(
              addresses: [
                _address(id: 'addr-1', name: 'Ali Khan', isDefault: true),
                _address(
                  id: 'addr-2',
                  name: 'Sara Ahmed',
                  line1: '9 Jinnah Avenue',
                ),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);

      // Addresses + default selected.
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      // COD + notes + coupon sections.
      expect(find.text('Payment method'), findsOneWidget);
      expect(find.text('Pay when your order arrives.'), findsOneWidget);
      expect(find.text('Order note (optional)'), findsOneWidget);
      // Summary + CTA.
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('PKR 129999.00'), findsWidgets);
      expect(find.text('2 item(s)'), findsOneWidget);
      expect(find.text('Place order'), findsOneWidget);
    });

    testWidgets('an alternate address can be selected', (tester) async {
      await tester.pumpWidget(
        _app(
          overrides: _overrides(
            profile: _FakeProfileRepository(
              addresses: [
                _address(id: 'addr-1', name: 'Ali Khan', isDefault: true),
                _address(id: 'addr-2', name: 'Sara Ahmed'),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Sara Ahmed'));
      await tester.pump();

      // Selection moved to the alternate tile: exactly one checked, and it is
      // inside Sara's card.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Sara Ahmed'),
            matching: find.byType(Card),
          ),
          matching: find.byIcon(Icons.radio_button_checked),
        ),
        findsOneWidget,
      );
    });
  });

  group('D. address requirement', () {
    testWidgets('no address disables Place order and offers to add one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(overrides: _overrides(profile: _FakeProfileRepository())),
      );
      await _settle(tester);

      expect(find.text('You have no saved addresses yet.'), findsOneWidget);
      // Place order is present but disabled (no selectable address).
      final button = tester.widget<LoadingButton>(find.byType(LoadingButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Add an address'));
      await tester.pump();
      await tester.pump();
      expect(find.text('ADDRESSES'), findsOneWidget);
    });
  });

  group('E. success', () {
    testWidgets('Place order submits once and navigates to the order', (
      tester,
    ) async {
      final checkout = _FakeCheckoutRepository();
      await tester.pumpWidget(
        _app(
          overrides: _overrides(
            checkout: checkout,
            profile: _FakeProfileRepository(
              addresses: [_address(isDefault: true)],
            ),
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Place order'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(checkout.placeCalls, 1); // exactly once
      expect(find.text('ORDER_order-1'), findsOneWidget); // navigated
    });
  });

  group('F. failure', () {
    testWidgets('failure surfaces feedback and stays on checkout', (
      tester,
    ) async {
      final checkout = _FakeCheckoutRepository(
        error: const Failure(message: 'Insufficient stock for Ring.'),
      );
      await tester.pumpWidget(
        _app(
          overrides: _overrides(
            checkout: checkout,
            profile: _FakeProfileRepository(
              addresses: [_address(isDefault: true)],
            ),
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Place order'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Insufficient stock for Ring.'), findsOneWidget);
      expect(find.text('ORDER_order-1'), findsNothing); // no navigation
      expect(find.text('Place order'), findsOneWidget); // still usable
    });
  });

  group('G. responsive', () {
    for (final (label, width, scale) in const [
      ('320px / 1.0x', 320.0, 1.0),
      ('375px / 1.3x', 375.0, 1.3),
    ]) {
      testWidgets('no overflow at $label', (tester) async {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            textScale: scale,
            overrides: _overrides(
              profile: _FakeProfileRepository(
                addresses: [
                  _address(
                    isDefault: true,
                    name: 'Muhammad Abdullah Khan',
                    line1: '221-B Gulberg III, Main Boulevard, Near Liberty',
                  ),
                ],
              ),
            ),
          ),
        );
        await _settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Place order'), findsOneWidget);
        expect(find.text('PKR 129999.00'), findsWidgets);
        expect(find.text('Pay when your order arrives.'), findsOneWidget);
      });
    }
  });

  group('H. dark mode', () {
    testWidgets('renders without exception in dark theme', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          theme: ThemeData(brightness: Brightness.dark),
          overrides: _overrides(
            profile: _FakeProfileRepository(
              addresses: [_address(isDefault: true)],
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Place order'), findsOneWidget);
    });
  });

  group('I. guest guard', () {
    testWidgets('guest is redirected to login', (tester) async {
      await tester.pumpWidget(
        _app(
          overrides: _overrides(
            checkout: _FakeCheckoutRepository(authenticated: false),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('LOGIN'), findsOneWidget);
    });
  });
}
