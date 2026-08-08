import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/core_providers.dart';
import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/guest_token_service.dart';
import '../data/repositories/supabase_cart_repository.dart';
import '../domain/entities/cart_view.dart';
import '../domain/repositories/cart_repository.dart';

/// Guest-token service bound to the shared secure storage.
final guestTokenServiceProvider = Provider<GuestTokenService>((ref) {
  return GuestTokenService(storage: ref.watch(secureStorageServiceProvider));
});

/// Repository binding for the cart (lazy services — stays test-safe without an
/// initialized Supabase client).
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  const service = SupabaseService();
  return SupabaseCartRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
    authService: const SupabaseAuthService(supabaseService: service),
    guestTokenService: ref.watch(guestTokenServiceProvider),
  );
});

enum CartStatus { initial, loading, success, failure }

class CartState {
  const CartState({this.status = CartStatus.initial, this.cart, this.message});

  final CartStatus status;
  final CartView? cart;
  final String? message;

  bool get isLoading => status == CartStatus.loading;
  bool get isEmpty => cart?.isEmpty ?? true;
  bool get isGuest => cart?.isGuest ?? false;
  int get itemCount => cart?.itemCount ?? 0;

  CartState copyWith({
    CartStatus? status,
    CartView? cart,
    String? message,
    bool clearMessage = false,
  }) {
    return CartState(
      status: status ?? this.status,
      cart: cart ?? this.cart,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref.watch(cartRepositoryProvider));
});

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(this._repository) : super(const CartState());

  final CartRepository _repository;

  Future<void> load() => _run(_repository.getCart);

  Future<void> addItem(String productVariantId, {int quantity = 1}) {
    return _run(
      () => _repository.addItem(
        productVariantId: productVariantId,
        quantity: quantity,
      ),
    );
  }

  Future<void> updateQuantity(String productVariantId, int quantity) {
    return _run(
      () => _repository.updateQuantity(
        productVariantId: productVariantId,
        quantity: quantity,
      ),
    );
  }

  Future<void> removeItem(String productVariantId) {
    return _run(
      () => _repository.removeItem(productVariantId: productVariantId),
    );
  }

  Future<void> clear() => _run(_repository.clearCart);

  Future<void> _run(Future<CartView> Function() action) async {
    // Keep the current cart visible while the mutation is in flight.
    state = state.copyWith(status: CartStatus.loading, clearMessage: true);
    try {
      final cart = await action();
      state = CartState(status: CartStatus.success, cart: cart);
    } catch (error) {
      state = state.copyWith(
        status: CartStatus.failure,
        message: error.toString(),
      );
    }
  }
}
