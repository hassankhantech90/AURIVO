import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/core_providers.dart';
import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/guest_token_service.dart';
import '../data/repositories/supabase_cart_repository.dart';
import '../domain/entities/cart_item.dart';
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
  final notifier = CartNotifier(ref.watch(cartRepositoryProvider));
  // Reset the cached cart whenever the effective auth identity changes — login,
  // logout, or switching users — so one account's count/items can never remain
  // visible under another session (the badge and the Cart screen both read this
  // state). A token refresh that keeps the same user id does NOT reset. The
  // repository still re-resolves the session per call for every read/write.
  String? identity(SessionState? s) =>
      (s != null && s.isAuthenticated) ? s.user?.id : null;
  ref.listen<SessionState>(sessionProvider, (previous, next) {
    if (identity(previous) != identity(next)) {
      ref.read(cartRepositoryProvider).clearSessionCache();
      notifier.reset();
    }
  });
  return notifier;
});

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(this._repository) : super(const CartState());

  final CartRepository _repository;

  // Monotonic token so that, when taps overlap, only the most recent mutation's
  // authoritative result is applied (older in-flight results are discarded).
  int _seq = 0;

  /// Clears the cached cart back to its initial state (no items, count 0).
  /// Invoked when the auth identity changes so no previous session's cart
  /// remains visible; the next [load] fetches the current session's cart.
  void reset() {
    _seq++; // supersede any in-flight mutation so it can't repaint this reset
    state = const CartState();
  }

  Future<void> load() => _run(_repository.getCart);

  Future<void> addItem(String productVariantId, {int quantity = 1}) {
    final cart = state.cart;
    final existing = _lineFor(cart, productVariantId);
    // Existing line: optimistically bump its quantity (we have its price). A
    // brand-new line has no local price/title, so fall through to a normal load
    // (now faster thanks to the repository caching).
    if (cart != null && existing != null) {
      return _optimistic(
        _replaceQuantity(cart, productVariantId, existing.quantity + quantity),
        () => _repository.addItem(
          productVariantId: productVariantId,
          quantity: quantity,
        ),
      );
    }
    return _run(
      () => _repository.addItem(
        productVariantId: productVariantId,
        quantity: quantity,
      ),
    );
  }

  Future<void> updateQuantity(String productVariantId, int quantity) {
    final cart = state.cart;
    if (cart == null) {
      return _run(
        () => _repository.updateQuantity(
          productVariantId: productVariantId,
          quantity: quantity,
        ),
      );
    }
    return _optimistic(
      _replaceQuantity(cart, productVariantId, quantity),
      () => _repository.updateQuantity(
        productVariantId: productVariantId,
        quantity: quantity,
      ),
    );
  }

  Future<void> removeItem(String productVariantId) {
    final cart = state.cart;
    if (cart == null) {
      return _run(
        () => _repository.removeItem(productVariantId: productVariantId),
      );
    }
    return _optimistic(
      _replaceQuantity(cart, productVariantId, 0),
      () => _repository.removeItem(productVariantId: productVariantId),
    );
  }

  Future<void> clear() => _run(_repository.clearCart);

  /// Paints [optimistic] instantly, then reconciles with the authoritative
  /// result from [action]. On failure it reverts to the pre-tap cart. Stale
  /// results (superseded by a newer tap or a reset) are ignored.
  Future<void> _optimistic(
    CartView optimistic,
    Future<CartView> Function() action,
  ) async {
    final previous = state;
    final token = ++_seq;
    state = CartState(status: CartStatus.success, cart: optimistic);
    try {
      final cart = await action();
      if (token == _seq) state = CartState(status: CartStatus.success, cart: cart);
    } catch (error) {
      if (token == _seq) {
        state = CartState(
          status: CartStatus.failure,
          cart: previous.cart,
          message: error.toString(),
        );
      }
    }
  }

  Future<void> _run(Future<CartView> Function() action) async {
    // Keep the current cart visible while the mutation is in flight.
    final token = ++_seq;
    state = state.copyWith(status: CartStatus.loading, clearMessage: true);
    try {
      final cart = await action();
      if (token == _seq) state = CartState(status: CartStatus.success, cart: cart);
    } catch (error) {
      if (token == _seq) {
        state = state.copyWith(
          status: CartStatus.failure,
          message: error.toString(),
        );
      }
    }
  }

  CartItem? _lineFor(CartView? cart, String variantId) {
    if (cart == null) return null;
    for (final item in cart.items) {
      if (item.productVariantId == variantId) return item;
    }
    return null;
  }

  /// Rebuilds [view] with [variantId]'s quantity set to [quantity] (line removed
  /// when <= 0) and totals recomputed locally for an instant preview. The
  /// database-authoritative totals replace these when the write returns.
  CartView _replaceQuantity(CartView view, String variantId, int quantity) {
    final items = <CartItem>[];
    for (final item in view.items) {
      if (item.productVariantId != variantId) {
        items.add(item);
      } else if (quantity > 0) {
        items.add(item.copyWith(quantity: quantity));
      }
    }
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final grand = subtotal - view.cart.discountTotal;
    return CartView(
      cart: view.cart.copyWith(
        subtotal: subtotal,
        grandTotal: grand < 0 ? 0 : grand,
      ),
      items: items,
    );
  }
}
