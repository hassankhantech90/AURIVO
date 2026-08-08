/// Ordering options for product listings, each backed by an existing index.
enum ProductSort {
  /// Newest first (`products_created_at_idx`).
  newest,

  /// Featured first, then newest (`products_approved_idx`).
  featured,

  /// Lowest price first (`products_base_price_idx`).
  priceLowToHigh,

  /// Highest price first (`products_base_price_idx`).
  priceHighToLow,
}
