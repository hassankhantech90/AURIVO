import '../../../../core/utils/db_parsing.dart';

/// A cart line item (`public.cart_items`). [unitPriceSnapshot] is the price
/// captured when the item was added; [lineTotal] is derived for display.
class CartItem {
  const CartItem({
    required this.id,
    required this.cartId,
    required this.productVariantId,
    required this.quantity,
    required this.unitPriceSnapshot,
    this.currency = 'PKR',
    this.createdAt,
    this.updatedAt,
    this.productTitle,
  });

  final String id;
  final String cartId;
  final String productVariantId;
  final int quantity;
  final double unitPriceSnapshot;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The owning product's title, resolved by the data layer for display (not a
  /// `cart_items` column). Null when it could not be resolved (e.g. the product
  /// is no longer publicly visible) — the UI then falls back to a generic label.
  final String? productTitle;

  double get lineTotal => unitPriceSnapshot * quantity;

  CartItem copyWith({String? productTitle, int? quantity}) => CartItem(
    id: id,
    cartId: cartId,
    productVariantId: productVariantId,
    quantity: quantity ?? this.quantity,
    unitPriceSnapshot: unitPriceSnapshot,
    currency: currency,
    createdAt: createdAt,
    updatedAt: updatedAt,
    productTitle: productTitle ?? this.productTitle,
  );

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      cartId: map['cart_id'] as String,
      productVariantId: map['product_variant_id'] as String,
      quantity: parseInt(map['quantity']),
      unitPriceSnapshot: parseDouble(map['unit_price_snapshot']),
      currency: map['currency'] as String? ?? 'PKR',
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
