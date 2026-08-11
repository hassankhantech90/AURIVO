import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/cart/domain/entities/cart.dart';
import 'package:aurivo/features/cart/domain/entities/cart_item.dart';
import 'package:aurivo/features/cart/domain/entities/cart_view.dart';
import 'package:aurivo/features/cart/domain/repositories/cart_repository.dart';
import 'package:aurivo/features/cart/providers/cart_providers.dart';
import 'package:aurivo/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:aurivo/features/checkout/presentation/checkout_page.dart';
import 'package:aurivo/features/checkout/providers/checkout_providers.dart';
import 'package:aurivo/features/coupons/domain/entities/coupon.dart';
import 'package:aurivo/features/coupons/domain/entities/coupon_redemption.dart';
import 'package:aurivo/features/coupons/domain/repositories/coupon_repository.dart';
import 'package:aurivo/features/coupons/presentation/widgets/coupon_field.dart';
import 'package:aurivo/features/coupons/providers/coupon_providers.dart';
import 'package:aurivo/features/profile/domain/entities/address.dart';
import 'package:aurivo/features/profile/domain/repositories/profile_repository.dart';
import 'package:aurivo/features/profile/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeCheckoutRepository implements CheckoutRepository {
  @override
  bool get isAuthenticated => true;

  @override
  Future<String> placeOrder({
    required String cartId,
    required String addressId,
    String paymentMethod = 'cash_on_delivery',
    String? notes,
  }) async => 'order-1';
}

class _RecordingCouponRepository implements CouponRepository {
  _RecordingCouponRepository({this.redeemError});
  final Object? redeemError;
  int redeemCalls = 0;
  String? code;
  String? orderId;

  @override
  Future<List<Coupon>> getActiveCoupons({
    int limit = 20,
    int offset = 0,
  }) async => const [];

  @override
  Future<CouponRedemption> redeem({
    required String code,
    required String orderId,
  }) async {
    redeemCalls++;
    this.code = code;
    this.orderId = orderId;
    if (redeemError != null) throw redeemError!;
    return CouponRedemption(
      id: 'red-1',
      couponId: 'c1',
      profileId: 'p1',
      orderId: orderId,
      discountAmount: 250,
    );
  }
}

class _FakeCartRepository implements CartRepository {
  @override
  Future<CartView> getCart() async => CartView(
    cart: const Cart(id: 'cart-1', currency: 'PKR', grandTotal: 1000),
    items: const [
      CartItem(
        id: 'ci-1',
        cartId: 'cart-1',
        productVariantId: 'v1',
        quantity: 1,
        unitPriceSnapshot: 1000,
      ),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<List<Address>> getAddresses() async => const [
    Address(
      id: 'addr-1',
      profileId: 'p1',
      addressType: 'shipping',
      recipientName: 'Aiman',
      phone: '03000000000',
      addressLine1: '1 Mall Road',
      city: 'Lahore',
      province: 'Punjab',
      isDefault: true,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap({
  required CouponRepository couponRepo,
  required GlobalKey<NavigatorState> navKey,
}) {
  final router = GoRouter(
    navigatorKey: navKey,
    initialLocation: '/checkout',
    routes: [
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutPage()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            Scaffold(body: Text('order-page:${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      checkoutRepositoryProvider.overrideWithValue(_FakeCheckoutRepository()),
      couponRepositoryProvider.overrideWithValue(couponRepo),
      cartRepositoryProvider.overrideWithValue(_FakeCartRepository()),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('CouponField captures the entered code', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CouponField(controller: controller)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'WELCOME10');
    expect(controller.text, 'WELCOME10');
  });

  testWidgets('entering a coupon applies it after the order is created', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final coupon = _RecordingCouponRepository();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_wrap(couponRepo: coupon, navKey: navKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(CouponField),
        matching: find.byType(TextField),
      ),
      'SAVE10',
    );
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(coupon.redeemCalls, 1);
    expect(coupon.code, 'SAVE10');
    expect(coupon.orderId, 'order-1');
    // Navigated to the order despite (here) a successful coupon.
    expect(find.text('order-page:order-1'), findsOneWidget);
  });

  testWidgets('a failed coupon does not break the placed order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final coupon = _RecordingCouponRepository(
      redeemError: const Failure(message: 'Coupon is not valid.'),
    );
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_wrap(couponRepo: coupon, navKey: navKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(CouponField),
        matching: find.byType(TextField),
      ),
      'BADCODE',
    );
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(coupon.redeemCalls, 1);
    // Order still placed → navigation happened.
    expect(find.text('order-page:order-1'), findsOneWidget);
  });

  testWidgets('no coupon code skips redemption entirely', (tester) async {
    final coupon = _RecordingCouponRepository();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_wrap(couponRepo: coupon, navKey: navKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(coupon.redeemCalls, 0);
    expect(find.text('order-page:order-1'), findsOneWidget);
  });
}
