import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:aurivo/features/checkout/providers/checkout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCheckoutRepository implements CheckoutRepository {
  _FakeCheckoutRepository({this.authenticated = true, this.error});

  final bool authenticated;
  final Object? error;
  Map<String, Object?>? lastCall;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Future<String> placeOrder({
    required String cartId,
    required String addressId,
    String paymentMethod = 'cash_on_delivery',
    String? notes,
  }) async {
    lastCall = {
      'cartId': cartId,
      'addressId': addressId,
      'paymentMethod': paymentMethod,
      'notes': notes,
    };
    if (error != null) throw error!;
    return 'order-1';
  }
}

ProviderContainer _container(CheckoutRepository repo) {
  final container = ProviderContainer(
    overrides: [checkoutRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts idle', () {
    final container = _container(_FakeCheckoutRepository());
    expect(container.read(checkoutProvider).status, CheckoutStatus.idle);
  });

  test('placeOrder success sets success state with the order id', () async {
    final repo = _FakeCheckoutRepository();
    final container = _container(repo);

    final orderId = await container
        .read(checkoutProvider.notifier)
        .placeOrder(cartId: 'c1', addressId: 'a1');

    expect(orderId, 'order-1');
    final state = container.read(checkoutProvider);
    expect(state.status, CheckoutStatus.success);
    expect(state.orderId, 'order-1');
    expect(repo.lastCall!['cartId'], 'c1');
    expect(repo.lastCall!['paymentMethod'], 'cash_on_delivery');
  });

  test('placeOrder failure sets failure state with message', () async {
    final container = _container(
      _FakeCheckoutRepository(error: const Failure(message: 'Cart is empty.')),
    );

    final orderId = await container
        .read(checkoutProvider.notifier)
        .placeOrder(cartId: 'c1', addressId: 'a1');

    expect(orderId, isNull);
    final state = container.read(checkoutProvider);
    expect(state.status, CheckoutStatus.failure);
    expect(state.message, 'Cart is empty.');
  });

  test('isAuthenticated passes through to the repository', () {
    final container = _container(_FakeCheckoutRepository(authenticated: false));
    expect(container.read(checkoutProvider.notifier).isAuthenticated, isFalse);
  });

  test('reset returns to idle', () async {
    final container = _container(_FakeCheckoutRepository());
    await container
        .read(checkoutProvider.notifier)
        .placeOrder(cartId: 'c1', addressId: 'a1');
    container.read(checkoutProvider.notifier).reset();
    expect(container.read(checkoutProvider).status, CheckoutStatus.idle);
  });
}
