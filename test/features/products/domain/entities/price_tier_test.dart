import 'package:aurivo/features/products/domain/entities/price_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PriceTier.fromMap parses fields and coerces numeric types', () {
    final tier = PriceTier.fromMap({
      'id': 't1',
      'product_id': 'p1',
      'min_quantity': 10,
      'unit_price': '82000.00', // numeric may arrive as a string
    });

    expect(tier.id, 't1');
    expect(tier.productId, 'p1');
    expect(tier.minQuantity, 10);
    expect(tier.unitPrice, 82000);
  });
}
