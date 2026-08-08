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
  });

  final String id;
  final String cartId;
  final String productVariantId;
  final int quantity;
  final double unitPriceSnapshot;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get lineTotal => unitPriceSnapshot * quantity;

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
