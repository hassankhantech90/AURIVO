import '../../../../core/utils/db_parsing.dart';

/// A wholesale price break for a product: buying [minQuantity] units or more
/// drops the per-unit price to [unitPrice]. Currency is the parent product's.
class PriceTier {
  const PriceTier({
    required this.id,
    required this.productId,
    required this.minQuantity,
    required this.unitPrice,
  });

  final String id;
  final String productId;
  final int minQuantity;
  final double unitPrice;

  factory PriceTier.fromMap(Map<String, dynamic> map) => PriceTier(
    id: map['id'] as String,
    productId: map['product_id'] as String,
    minQuantity: parseInt(map['min_quantity']),
    unitPrice: parseDouble(map['unit_price']),
  );
}
