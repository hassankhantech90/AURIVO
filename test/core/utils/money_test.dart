import 'package:aurivo/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMoney', () {
    test('groups thousands and drops decimals for whole amounts', () {
      expect(formatMoney(485000, currency: 'PKR'), 'PKR 485,000');
      expect(formatMoney(129999, currency: 'PKR'), 'PKR 129,999');
      expect(formatMoney(1000, currency: 'PKR'), 'PKR 1,000');
    });

    test('leaves sub-thousand amounts ungrouped', () {
      expect(formatMoney(999, currency: 'PKR'), 'PKR 999');
      expect(formatMoney(0, currency: 'PKR'), 'PKR 0');
    });

    test('keeps two decimals for fractional amounts', () {
      expect(formatMoney(1299.5, currency: 'PKR'), 'PKR 1,299.50');
      expect(formatMoney(1234567.89, currency: 'USD'), 'USD 1,234,567.89');
    });

    test('groups millions', () {
      expect(formatMoney(1234567, currency: 'PKR'), 'PKR 1,234,567');
    });

    test('handles negatives', () {
      expect(formatMoney(-485000, currency: 'PKR'), 'PKR -485,000');
    });

    test('defaults the currency to USD', () {
      expect(formatMoney(2500), 'USD 2,500');
    });
  });
}
