import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_detail.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/order_status_event.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/tracking_event.dart';
import '../../domain/repositories/order_repository.dart';
import '../order_failure_mapper.dart';

/// Supabase-backed [OrderRepository].
///
/// Reads are plain RLS-scoped SELECTs (the buyer only ever sees their own rows
/// via `orders.profile_id = current_profile_id()` and the dependent policies).
/// Cancellation is delegated to the `cancel_order` SECURITY DEFINER RPC — the
/// buyer app never writes to orders/payments/shipments directly.
class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _ordersTable = 'orders';
  static const String _orderItemsTable = 'order_items';
  static const String _statusHistoryTable = 'order_status_history';
  static const String _paymentsTable = 'payments';
  static const String _shipmentsTable = 'shipments';
  static const String _trackingEventsTable = 'tracking_events';

  @override
  Future<List<Order>> getOrders({int limit = 50, int offset = 0}) async {
    try {
      final rows = await _database.list(
        table: _ordersTable,
        orderBy: 'placed_at',
        ascending: false,
        limit: limit,
        offset: offset,
      );
      return rows.map(Order.fromMap).toList();
    } catch (error) {
      throw OrderFailureMapper.map(error);
    }
  }

  @override
  Future<OrderDetail> getOrder(String orderId) async {
    try {
      final orderRows = await _database.list(
        table: _ordersTable,
        filters: {'id': orderId},
        limit: 1,
      );
      if (orderRows.isEmpty) {
        throw const Failure(message: 'Order not found.');
      }
      final order = Order.fromMap(orderRows.first);

      final itemRows = await _database.list(
        table: _orderItemsTable,
        filters: {'order_id': orderId},
        orderBy: 'created_at',
      );

      final historyRows = await _database.list(
        table: _statusHistoryTable,
        filters: {'order_id': orderId},
        orderBy: 'created_at',
        ascending: false,
      );

      final paymentRows = await _database.list(
        table: _paymentsTable,
        filters: {'order_id': orderId},
        limit: 1,
      );

      final shipmentRows = await _database.list(
        table: _shipmentsTable,
        filters: {'order_id': orderId},
        orderBy: 'created_at',
      );
      final shipments = shipmentRows.map(Shipment.fromMap).toList();

      final trackingEvents = await _loadTrackingEvents(
        shipments.map((s) => s.id).toList(),
      );

      return OrderDetail(
        order: order,
        items: itemRows.map(OrderItem.fromMap).toList(),
        statusHistory: historyRows.map(OrderStatusEvent.fromMap).toList(),
        payment: paymentRows.isEmpty
            ? null
            : Payment.fromMap(paymentRows.first),
        shipments: shipments,
        trackingEvents: trackingEvents,
      );
    } catch (error) {
      throw OrderFailureMapper.map(error);
    }
  }

  Future<List<TrackingEvent>> _loadTrackingEvents(
    List<String> shipmentIds,
  ) async {
    if (shipmentIds.isEmpty) return const [];
    final rows = await _database.list(
      table: _trackingEventsTable,
      whereIn: {'shipment_id': shipmentIds},
      orderBy: 'event_time',
      ascending: false,
    );
    return rows.map(TrackingEvent.fromMap).toList();
  }

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) async {
    try {
      await _database.rpc(
        functionName: 'cancel_order',
        params: {
          'p_order_id': orderId,
          if (reason != null && reason.trim().isNotEmpty)
            'p_reason': reason.trim(),
        },
      );
    } catch (error) {
      throw OrderFailureMapper.map(error);
    }
  }
}
