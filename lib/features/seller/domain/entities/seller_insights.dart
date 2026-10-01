import '../../../../core/utils/db_parsing.dart';

/// A product in the seller's top sellers.
class TopProduct {
  const TopProduct({
    required this.productId,
    required this.title,
    required this.units,
    required this.revenue,
  });

  final String productId;
  final String title;
  final int units;
  final double revenue;
}

/// A variant at or below its low-stock threshold.
class LowStockItem {
  const LowStockItem({
    required this.productId,
    required this.title,
    required this.available,
    required this.threshold,
    this.sku,
  });

  final String productId;
  final String title;
  final String? sku;
  final int available;
  final int threshold;
}

/// Store performance from `seller_insights(p_days)` (Requirements Doc §5).
class SellerInsights {
  const SellerInsights({
    this.views = 0,
    this.wishlistAdds = 0,
    this.orders = 0,
    this.unitsSold = 0,
    this.revenue = 0,
    this.conversionPct,
    this.topProducts = const [],
    this.dailyRevenue = const [],
    this.lowStock = const [],
  });

  final int views;
  final int wishlistAdds;
  final int orders;
  final int unitsSold;
  final double revenue;

  /// Orders per 100 product views; null without view data.
  final double? conversionPct;
  final List<TopProduct> topProducts;

  /// Last 14 days, oldest first: (day, revenue).
  final List<(DateTime, double)> dailyRevenue;
  final List<LowStockItem> lowStock;

  /// View tracking is new, so early on orders can exceed recorded views;
  /// conversion is only meaningful once views >= orders.
  bool get hasMeaningfulConversion =>
      conversionPct != null && views >= orders && views > 0;

  factory SellerInsights.fromMap(Map<String, dynamic> map) {
    return SellerInsights(
      views: parseInt(map['views']),
      wishlistAdds: parseInt(map['wishlist_adds']),
      orders: parseInt(map['orders']),
      unitsSold: parseInt(map['units_sold']),
      revenue: parseDouble(map['revenue']),
      conversionPct: parseDoubleOrNull(map['conversion_pct']),
      topProducts: [
        for (final row in (map['top_products'] as List? ?? const []))
          if (row is Map)
            TopProduct(
              productId: '${row['product_id']}',
              title: '${row['title'] ?? ''}',
              units: parseInt(row['units']),
              revenue: parseDouble(row['revenue']),
            ),
      ],
      dailyRevenue: [
        for (final row in (map['daily_revenue'] as List? ?? const []))
          if (row is Map && DateTime.tryParse('${row['day']}') != null)
            (DateTime.parse('${row['day']}'), parseDouble(row['revenue'])),
      ],
      lowStock: [
        for (final row in (map['low_stock'] as List? ?? const []))
          if (row is Map)
            LowStockItem(
              productId: '${row['product_id']}',
              title: '${row['title'] ?? ''}',
              sku: row['sku'] as String?,
              available: parseInt(row['available']),
              threshold: parseInt(row['threshold']),
            ),
      ],
    );
  }
}
