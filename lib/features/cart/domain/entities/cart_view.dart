import 'cart.dart';
import 'cart_item.dart';

/// Aggregate read shape for the cart screen: the cart header plus its items.
class CartView {
  const CartView({required this.cart, this.items = const []});

  final Cart cart;
  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;
  bool get isGuest => cart.isGuest;

  /// Total number of units across all lines.
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Number of distinct line items.
  int get lineCount => items.length;
}
