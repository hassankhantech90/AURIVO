/// Contract for placing an order from an active cart.
///
/// The single write path into orders/payments is the server-side
/// `checkout_cart` SECURITY DEFINER RPC — this repository only forwards the
/// cart id, chosen address, payment method, and notes. It never sends or
/// computes prices, subtotals, totals, tax, shipping, or discounts; the RPC is
/// authoritative and also performs all stock validation and reservation.
///
/// Implementations must never surface raw Supabase exceptions; all failures are
/// mapped to the shared `Failure` type.
abstract class CheckoutRepository {
  /// Whether there is an authenticated session. Guest carts cannot be checked
  /// out — the RPC rejects them — so the UI gates on this before submitting.
  bool get isAuthenticated;

  /// Places an order from [cartId] shipping to [addressId], returning the new
  /// order id. [paymentMethod] defaults to cash on delivery (the MVP's only
  /// method). [notes] is an optional buyer note.
  Future<String> placeOrder({
    required String cartId,
    required String addressId,
    String paymentMethod,
    String? notes,
  });
}
