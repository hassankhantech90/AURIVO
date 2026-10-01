import '../../../../core/utils/db_parsing.dart';

/// Admin dashboard figures from `admin_dashboard_stats(p_days)`. Order
/// figures cover the chosen window; queue counts are always current.
class AdminDashboardStats {
  const AdminDashboardStats({
    this.gmv = 0,
    this.orders = 0,
    this.completedOrders = 0,
    this.paidOrders = 0,
    this.pendingFulfilment = 0,
    this.cancelledOrders = 0,
    this.refundedOrders = 0,
    this.averageOrderValue = 0,
    this.activeSellers = 0,
    this.openDisputes = 0,
    this.openReturns = 0,
    this.pendingProducts = 0,
    this.pendingSellers = 0,
    this.pendingBusinesses = 0,
    this.dailyGmv = const [],
  });

  final double gmv;
  final int orders;
  final int completedOrders;
  final int paidOrders;
  final int pendingFulfilment;
  final int cancelledOrders;
  final int refundedOrders;
  final double averageOrderValue;
  final int activeSellers;
  final int openDisputes;
  final int openReturns;
  final int pendingProducts;
  final int pendingSellers;
  final int pendingBusinesses;

  /// Last 14 days, oldest first: (day, gmv).
  final List<(DateTime, double)> dailyGmv;

  int get moderationQueue => pendingProducts + pendingSellers + pendingBusinesses;

  factory AdminDashboardStats.fromMap(Map<String, dynamic> map) {
    return AdminDashboardStats(
      gmv: parseDouble(map['gmv']),
      orders: parseInt(map['orders']),
      completedOrders: parseInt(map['completed_orders']),
      paidOrders: parseInt(map['paid_orders']),
      pendingFulfilment: parseInt(map['pending_fulfilment']),
      cancelledOrders: parseInt(map['cancelled_orders']),
      refundedOrders: parseInt(map['refunded_orders']),
      averageOrderValue: parseDouble(map['average_order_value']),
      activeSellers: parseInt(map['active_sellers']),
      openDisputes: parseInt(map['open_disputes']),
      openReturns: parseInt(map['open_returns']),
      pendingProducts: parseInt(map['pending_products']),
      pendingSellers: parseInt(map['pending_sellers']),
      pendingBusinesses: parseInt(map['pending_businesses']),
      dailyGmv: [
        for (final row in (map['daily_gmv'] as List? ?? const []))
          if (row is Map && DateTime.tryParse('${row['day']}') != null)
            (DateTime.parse('${row['day']}'), parseDouble(row['gmv'])),
      ],
    );
  }
}
