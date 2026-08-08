import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/cart/domain/entities/cart.dart';
import 'package:aurivo/features/cart/domain/entities/cart_item.dart';
import 'package:aurivo/features/cart/domain/entities/cart_view.dart';
import 'package:aurivo/features/cart/domain/repositories/cart_repository.dart';
import 'package:aurivo/features/cart/providers/cart_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCartRepository implements CartRepository {
  _FakeCartRepository({this.authenticated = true, this.error});

  final bool authenticated;
  final Object? error;
  final Map<String, int> _items = {};

  @override
  bool get isAuthenticated => authenticated;

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
    _items[productVariantId] = (_items[productVariantId] ?? 0) + quantity;
    return _view();
  }

  @override
  Future<CartView> updateQuantity({
    required String productVariantId,
    required int quantity,
  }) async {
    if (error != null) throw error!;
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
}
