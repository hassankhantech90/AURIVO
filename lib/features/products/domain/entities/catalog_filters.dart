/// Optional catalogue filters that compose with the other `getProducts`
/// arguments (AND). Grouped in one value so new filters don't change the
/// repository signature. An empty instance ([isEmpty]) filters nothing.
class CatalogFilters {
  const CatalogFilters({
    this.minPrice,
    this.maxPrice,
    this.purity,
    this.jewelleryType,
    this.ids,
  });

  /// Inclusive bounds on the product's base (retail) price.
  final double? minPrice;
  final double? maxPrice;

  /// Purity / karat, matched case-insensitively (e.g. '22k', '925').
  final String? purity;

  /// Exact jewellery type (e.g. 'ring'), used for related products.
  final String? jewelleryType;

  /// Restrict to these product ids (e.g. recently viewed). Empty -> no results.
  final List<String>? ids;

  bool get hasPriceOrPurity =>
      minPrice != null ||
      maxPrice != null ||
      (purity != null && purity!.trim().isNotEmpty);

  bool get isEmpty => !hasPriceOrPurity && jewelleryType == null && ids == null;

  CatalogFilters copyWith({
    double? minPrice,
    double? maxPrice,
    String? purity,
    bool clearPrice = false,
    bool clearPurity = false,
  }) {
    return CatalogFilters(
      minPrice: clearPrice ? null : minPrice ?? this.minPrice,
      maxPrice: clearPrice ? null : maxPrice ?? this.maxPrice,
      purity: clearPurity ? null : purity ?? this.purity,
      jewelleryType: jewelleryType,
      ids: ids,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CatalogFilters &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.purity == purity &&
      other.jewelleryType == jewelleryType &&
      _sameIds(other.ids, ids);

  @override
  int get hashCode => Object.hash(
    minPrice,
    maxPrice,
    purity,
    jewelleryType,
    ids == null ? null : Object.hashAll(ids!),
  );

  static bool _sameIds(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
