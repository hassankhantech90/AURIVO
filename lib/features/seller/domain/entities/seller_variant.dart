import '../../../../core/utils/db_parsing.dart';

/// A seller-managed product variant (`public.product_variants`) — the full
/// inventory view (sku/stock) that the buyer-facing `ProductVariant` omits.
class SellerVariant {
  const SellerVariant({
    required this.id,
    required this.productId,
    required this.sku,
    this.barcode,
    this.weightGrams,
    required this.price,
    this.currency = 'PKR',
    this.comparePrice,
    this.stockQuantity = 0,
    this.reservedQuantity = 0,
    this.lowStockThreshold = 0,
    this.isActive = true,
  });

  final String id;
  final String productId;
  final String sku;
  final String? barcode;
  final double? weightGrams;
  final double price;
  final String currency;
  final double? comparePrice;
  final int stockQuantity;
  final int reservedQuantity;
  final int lowStockThreshold;
  final bool isActive;

  int get availableQuantity => stockQuantity - reservedQuantity;

  factory SellerVariant.fromMap(Map<String, dynamic> map) {
    return SellerVariant(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      sku: map['sku'] as String,
      barcode: map['barcode'] as String?,
      weightGrams: parseDoubleOrNull(map['weight_grams']),
      price: parseDouble(map['price']),
      currency: map['currency'] as String? ?? 'PKR',
      comparePrice: parseDoubleOrNull(map['compare_price']),
      stockQuantity: parseInt(map['stock_quantity']),
      reservedQuantity: parseInt(map['reserved_quantity']),
      lowStockThreshold: parseInt(map['low_stock_threshold']),
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

/// Editable variant fields (create/edit). `reserved_quantity` is system-owned
/// and never set from the UI.
class VariantDraft {
  const VariantDraft({
    required this.sku,
    required this.price,
    this.currency = 'PKR',
    this.comparePrice,
    this.weightGrams,
    this.barcode,
    this.stockQuantity = 0,
    this.lowStockThreshold = 0,
    this.isActive = true,
  });

  final String sku;
  final double price;
  final String currency;
  final double? comparePrice;
  final double? weightGrams;
  final String? barcode;
  final int stockQuantity;
  final int lowStockThreshold;
  final bool isActive;
}
