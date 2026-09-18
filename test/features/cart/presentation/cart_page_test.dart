import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/cart/domain/entities/cart.dart';
import 'package:aurivo/features/cart/domain/entities/cart_item.dart';
import 'package:aurivo/features/cart/domain/entities/cart_view.dart';
import 'package:aurivo/features/cart/domain/repositories/cart_repository.dart';
import 'package:aurivo/features/cart/presentation/cart_page.dart';
import 'package:aurivo/features/cart/providers/cart_providers.dart';
import 'package:aurivo/shared/widgets/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// Cart repository returning a fixed number of lines; counts clear calls.
class _FakeCartRepository implements CartRepository {
  _FakeCartRepository({this.items = 1});
  final int items;
  int clearCalls = 0;
  bool _cleared = false;

  CartView _view() {
    final list = _cleared
        ? const <CartItem>[]
        : List.generate(
            items,
            (i) => CartItem(
              id: 'i$i',
              cartId: 'c1',
              productVariantId: 'v$i',
              quantity: 1,
              unitPriceSnapshot: 1000,
            ),
          );
    return CartView(cart: const Cart(id: 'c1', profileId: 'p1'), items: list);
  }

  @override
  Future<CartView> getCart() async => _view();

  @override
  Future<CartView> clearCart() async {
    clearCalls++;
    _cleared = true;
    return _view();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Session notifier whose state the test drives directly.
class _TestSession extends SessionNotifier {
  _TestSession([SessionState? initial])
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

const SessionState _guest = SessionState(status: SessionStatus.unauthenticated);

Widget _app({required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(home: CartPage()),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(); // post-frame load
  await tester.pump(); // resolve
}

void main() {
  group('clear cart confirmation', () {
    testWidgets('tapping Clear opens a confirmation dialog', (tester) async {
      final repo = _FakeCartRepository(items: 2);
      await tester.pumpWidget(
        _app(overrides: [cartRepositoryProvider.overrideWithValue(repo)]),
      );
      await _settle(tester);

      await tester.tap(find.byTooltip('Clear cart'));
      await tester.pumpAndSettle();

      expect(find.text('Clear cart?'), findsOneWidget);
      expect(repo.clearCalls, 0); // nothing cleared yet
    });

    testWidgets('Cancel performs no clear mutation', (tester) async {
      final repo = _FakeCartRepository(items: 2);
      await tester.pumpWidget(
        _app(overrides: [cartRepositoryProvider.overrideWithValue(repo)]),
      );
      await _settle(tester);

      await tester.tap(find.byTooltip('Clear cart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep items'));
      await tester.pumpAndSettle();

      expect(repo.clearCalls, 0);
      expect(find.byTooltip('Remove'), findsNWidgets(2)); // items still there
    });

    testWidgets('Confirm clears exactly once and reaches the empty state', (
      tester,
    ) async {
      final repo = _FakeCartRepository(items: 2);
      await tester.pumpWidget(
        _app(overrides: [cartRepositoryProvider.overrideWithValue(repo)]),
      );
      await _settle(tester);

      await tester.tap(find.byTooltip('Clear cart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(repo.clearCalls, 1);
      expect(find.text('Your cart is empty'), findsOneWidget);
    });
  });

  group('auth identity change', () {
    testWidgets('previous account line items cannot remain during reload', (
      tester,
    ) async {
      final session = _TestSession(_authAs('user-A'));
      await tester.pumpWidget(
        _app(
          overrides: [
            cartRepositoryProvider.overrideWithValue(
              _FakeCartRepository(items: 2),
            ),
            sessionProvider.overrideWith((ref) => session),
          ],
        ),
      );
      await _settle(tester);

      // A's cart is shown.
      expect(find.text('Total'), findsOneWidget);
      expect(find.byTooltip('Remove'), findsNWidgets(2));

      // Switch identity A -> guest: cart resets immediately.
      session.set(_guest);
      await tester.pump();

      expect(find.byType(LoadingIndicator), findsOneWidget);
      expect(find.text('Total'), findsNothing); // A's summary gone
      expect(find.byTooltip('Remove'), findsNothing); // A's items gone
    });
  });
}
