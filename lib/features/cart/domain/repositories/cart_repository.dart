import '../entities/cart_view.dart';

/// Contract for the shopping cart. Implementations transparently use the
/// authenticated RLS-protected tables when signed in, or the token-scoped
/// guest-cart RPCs when not, and throw the shared `Failure` type rather than
/// raw Supabase exceptions.
///
/// All mutations return a fresh [CartView] reflecting the database-authoritative
/// state (including totals). Checkout is intentionally out of scope.
abstract class CartRepository {
  /// Whether there is an authenticated session (auth cart vs guest cart).
  bool get isAuthenticated;

  Future<CartView> getCart();

  /// Adds [quantity] of a variant, incrementing if the line already exists.
  Future<CartView> addItem({
    required String productVariantId,
    int quantity = 1,
  });

  /// Sets the absolute quantity for a variant; `quantity <= 0` removes the line.
  Future<CartView> updateQuantity({
    required String productVariantId,
    required int quantity,
  });

  Future<CartView> removeItem({required String productVariantId});

  Future<CartView> clearCart();
}
