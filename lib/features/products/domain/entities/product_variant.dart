import '../../../../core/utils/db_parsing.dart';

/// Buyer-facing sellable product variant (`public.product_variants`).
///
/// Internal inventory columns (`sku`, `barcode`, `stock_quantity`,
/// `reserved_quantity`, `low_stock_threshold`) are intentionally NOT selected
/// or exposed to the buyer catalogue. Only `is_active` variants are publicly
/// readable under RLS.
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.price,
    this.currency = 'PKR',
    this.comparePrice,
    this.weightGrams,
    this.isActive = true,
  });

  final String id;
  final String productId;
  final double price;
  final String currency;
  final double? comparePrice;
  final double? weightGrams;
  final bool isActive;

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      price: parseDouble(map['price']),
      currency: map['currency'] as String? ?? 'PKR',
      comparePrice: parseDoubleOrNull(map['compare_price']),
      weightGrams: parseDoubleOrNull(map['weight_grams']),
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
