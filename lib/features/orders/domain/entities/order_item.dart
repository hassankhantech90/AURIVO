import '../../../../core/utils/db_parsing.dart';

/// A line item on an order (`public.order_items`).
///
/// Every display field is a snapshot captured at checkout time by the
/// `checkout_cart` RPC, so order history stays stable even if the underlying
/// product, variant, or image later changes or is removed.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productVariantId,
    required this.sellerId,
    required this.productTitleSnapshot,
    this.variantTitleSnapshot,
    required this.skuSnapshot,
    this.imagePathSnapshot,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.currency = 'PKR',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderId;
  final String productId;
  final String productVariantId;
  final String sellerId;
  final String productTitleSnapshot;
  final String? variantTitleSnapshot;
  final String skuSnapshot;
  final String? imagePathSnapshot;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      productId: map['product_id'] as String,
      productVariantId: map['product_variant_id'] as String,
      sellerId: map['seller_id'] as String,
      productTitleSnapshot: map['product_title_snapshot'] as String,
      variantTitleSnapshot: map['variant_title_snapshot'] as String?,
      skuSnapshot: map['sku_snapshot'] as String,
      imagePathSnapshot: map['image_path_snapshot'] as String?,
      unitPrice: parseDouble(map['unit_price']),
      quantity: parseInt(map['quantity']),
      lineTotal: parseDouble(map['line_total']),
      currency: map['currency'] as String? ?? 'PKR',
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
