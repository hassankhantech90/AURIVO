import 'dart:async';

import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/cart/domain/entities/cart.dart';
import 'package:aurivo/features/cart/domain/entities/cart_item.dart';
import 'package:aurivo/features/cart/domain/entities/cart_view.dart';
import 'package:aurivo/features/cart/domain/repositories/cart_repository.dart';
import 'package:aurivo/features/cart/providers/cart_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _FakeCartRepository implements CartRepository {
  _FakeCartRepository({this.authenticated = true, this.error});

  final bool authenticated;
  final Object? error;
  final Map<String, int> _items = {};

  /// When set, mutations block on this until completed (to observe optimistic
  /// state before the server returns).
  Completer<void>? gate;

  /// When true, mutations (not [getCart]) throw — for revert tests.
  bool failMutations = false;
  int clearCacheCalls = 0;

  @override
  bool get isAuthenticated => authenticated;

  @override
  void clearSessionCache() => clearCacheCalls++;

  Future<void> _awaitMutation() async {
    if (gate != null) await gate!.future;
    if (failMutations) throw const Failure(message: 'sync failed');
  }

  CartView _view() {
    final items = _items.entries
        .map(
          (e) => CartItem(
            id: e.key,
            cartId: 'c1',
            productVariantId: e.key,
            quantity: e.value,
            unitPriceSnapshot: 1000,
          ),
        )
        .toList();
    return CartView(
      cart: Cart(id: 'c1', profileId: authenticated ? 'p1' : null),
      items: items,
    );
  }

  @override
  Future<CartView> getCart() async {
    if (error != null) throw error!;
    return _view();
  }

  @override
  Future<CartView> addItem({
    required String productVariantId,
    int quantity = 1,
  }) async {
    if (error != null) throw error!;
    await _awaitMutation();
    _items[productVariantId] = (_items[productVariantId] ?? 0) + quantity;
    return _view();
  }

  @override
  Future<CartView> updateQuantity({
    required String productVariantId,
    required int quantity,
  }) async {
    if (error != null) throw error!;
    await _awaitMutation();
    if (quantity <= 0) {
      _items.remove(productVariantId);
    } else {
      _items[productVariantId] = quantity;
    }
    return _view();
  }

  @override
  Future<CartView> removeItem({required String productVariantId}) async {
    if (error != null) throw error!;
    await _awaitMutation();
    _items.remove(productVariantId);
    return _view();
  }

  @override
  Future<CartView> clearCart() async {
    if (error != null) throw error!;
    _items.clear();
    return _view();
  }
}

ProviderContainer _container(CartRepository repo) {
  final container = ProviderContainer(
    overrides: [cartRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Session notifier whose state the test drives directly (no Supabase).
class _TestSession extends SessionNotifier {
  _TestSession()
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      );
  void set(SessionState next) => state = next;
}

SessionState _authAs(String userId) => SessionState(
  status: SessionStatus.authenticated,
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026).toIso8601String(),
  ),
);

const SessionState _guest = SessionState(status: SessionStatus.unauthenticated);

ProviderContainer _containerWithSession(
  CartRepository repo,
  _TestSession session,
) {
  final container = ProviderContainer(
    overrides: [
      cartRepositoryProvider.overrideWithValue(repo),
      sessionProvider.overrideWith((ref) => session),
    ],
  );
  addTearDown(container.dispose);
  // Keep cartProvider alive so its auth-change listener stays attached.
  container.listen(cartProvider, (_, _) {});
  return container;
}

void main() {
  test('starts in initial state', () {
    final container = _container(_FakeCartRepository());
    expect(container.read(cartProvider).status, CartStatus.initial);
  });

  test('load succeeds with an empty cart', () async {
    final container = _container(_FakeCartRepository());

    await container.read(cartProvider.notifier).load();

    final state = container.read(cartProvider);
    expect(state.status, CartStatus.success);
    expect(state.isEmpty, isTrue);
  });

  test('addItem and updateQuantity update item count', () async {
    final container = _container(_FakeCartRepository());
    final notifier = container.read(cartProvider.notifier);

    await notifier.addItem('v1', quantity: 2);
    expect(container.read(cartProvider).itemCount, 2);

    await notifier.updateQuantity('v1', 5);
    expect(container.read(cartProvider).itemCount, 5);

    await notifier.removeItem('v1');
    expect(container.read(cartProvider).isEmpty, isTrue);
  });

  test('guest repository yields a guest cart state', () async {
    final container = _container(_FakeCartRepository(authenticated: false));

    await container.read(cartProvider.notifier).load();

    expect(container.read(cartProvider).isGuest, isTrue);
  });

  test('maps repository failure to failure state', () async {
    final container = _container(
      _FakeCartRepository(error: const Failure(message: 'offline')),
    );

    await container.read(cartProvider.notifier).load();

    final state = container.read(cartProvider);
    expect(state.status, CartStatus.failure);
    expect(state.message, 'offline');
  });

  group('auth identity change resets the cart', () {
    test('A -> logout/guest clears the cached cart', () async {
      final session = _TestSession();
      final container = _containerWithSession(_FakeCartRepository(), session);

      session.set(_authAs('user-A'));
      await container.read(cartProvider.notifier).addItem('v1', quantity: 3);
      expect(container.read(cartProvider).itemCount, 3);

      session.set(_guest); // logout

      final state = container.read(cartProvider);
      expect(state.itemCount, 0);
      expect(state.cart, isNull);
      expect(state.status, CartStatus.initial);
    });

    test('A -> B clears A before B is shown', () async {
      final session = _TestSession();
      final container = _containerWithSession(_FakeCartRepository(), session);

      session.set(_authAs('user-A'));
      await container.read(cartProvider.notifier).addItem('v1', quantity: 2);
      expect(container.read(cartProvider).itemCount, 2);

      session.set(_authAs('user-B')); // switch user

      expect(container.read(cartProvider).itemCount, 0);
      expect(container.read(cartProvider).cart, isNull);
    });

    test('same-user token refresh does NOT reset the cart', () async {
      final session = _TestSession();
      final container = _containerWithSession(_FakeCartRepository(), session);

      session.set(_authAs('user-A'));
      await container.read(cartProvider.notifier).addItem('v1', quantity: 4);
      expect(container.read(cartProvider).itemCount, 4);

      // A new SessionState object for the SAME user id (e.g. token refresh).
      session.set(_authAs('user-A'));

      expect(container.read(cartProvider).itemCount, 4); // preserved
    });
  });

  group('optimistic mutations', () {
    test('updateQuantity applies before the server returns', () async {
      final repo = _FakeCartRepository();
      final container = _container(repo);
      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem('v1', quantity: 2); // seed an existing line
      expect(container.read(cartProvider).itemCount, 2);

      repo.gate = Completer<void>();
      final future = notifier.updateQuantity('v1', 5);
      // Applied synchronously — before the gated server call resolves.
      expect(container.read(cartProvider).itemCount, 5);

      repo.gate!.complete();
      await future;
      expect(container.read(cartProvider).itemCount, 5);
    });

    test('a failed mutation reverts to the previous cart', () async {
      final repo = _FakeCartRepository();
      final container = _container(repo);
      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem('v1', quantity: 2);

      repo.failMutations = true;
      await notifier.updateQuantity('v1', 9); // optimistic 9, then fails

      final state = container.read(cartProvider);
      expect(state.itemCount, 2); // reverted
      expect(state.status, CartStatus.failure);
    });

    test('auth identity change clears the repository cache', () async {
      final repo = _FakeCartRepository();
      final session = _TestSession();
      final container = _containerWithSession(repo, session);

      session.set(_authAs('user-A'));
      await container.read(cartProvider.notifier).addItem('v1');
      session.set(_authAs('user-B'));

      expect(repo.clearCacheCalls, greaterThanOrEqualTo(1));
    });
  });
}
