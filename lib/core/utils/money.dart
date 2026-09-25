/// Formats a monetary [amount] as a currency-prefixed, thousands-grouped
/// string, e.g. `formatMoney(485000, currency: 'PKR') == 'PKR 485,000'`.
///
/// Whole amounts render without decimals (the norm for PKR jewellery pricing);
/// fractional amounts keep two decimals (`'PKR 1,299.50'`). Grouping is applied
/// to the integer part only. No `intl` dependency — the grouping is done here so
/// every price surface formats identically through [PriceWidget].
String formatMoney(num amount, {String currency = 'USD'}) {
  final isWhole = amount == amount.truncateToDouble();
  final fixed = isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);

  final negative = fixed.startsWith('-');
  final unsigned = negative ? fixed.substring(1) : fixed;
  final dot = unsigned.indexOf('.');
  final intPart = dot == -1 ? unsigned : unsigned.substring(0, dot);
  final fractionPart = dot == -1 ? '' : unsigned.substring(dot); // includes '.'

  final grouped = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i != 0 && (intPart.length - i) % 3 == 0) grouped.write(',');
    grouped.write(intPart[i]);
  }

  return '$currency ${negative ? '-' : ''}$grouped$fractionPart';
}
