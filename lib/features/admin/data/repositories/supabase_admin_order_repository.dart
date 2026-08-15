import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/entities/order_detail.dart';
import '../../../orders/domain/entities/order_item.dart';
import '../../../orders/domain/entities/order_status_event.dart';
import '../../../orders/domain/entities/payment.dart';
import '../../../orders/domain/entities/shipment.dart';
import '../../../orders/domain/entities/tracking_event.dart';
import '../../domain/repositories/admin_order_repository.dart';
import '../admin_failure_mapper.dart';

/// Supabase-backed [AdminOrderRepository]. Reads/writes rely on the admin RLS
/// arm; status changes use the audited `order_status_history` path and
/// cancellation uses the `admin_cancel_order` RPC. It never bypasses security.
class SupabaseAdminOrderRepository implements AdminOrderRepository {
  SupabaseAdminOrderRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const _orders = 'orders';
  static const _orderItems = 'order_items';
  static const _statusHistory = 'order_status_history';
  static const _payments = 'payments';
  static const _shipments = 'shipments';
  static const _trackingEvents = 'tracking_events';

  @override
  Future<List<Order>> listOrders({String? status}) async {
    try {
      final rows = await _database.list(
        table: _orders,
        filters: {'status': ?status},
        orderBy: 'placed_at',
        ascending: false,
        limit: 200,
      );
      return rows
          .where((r) => r['deleted_at'] == null)
          .map(Order.fromMap)
          .toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<OrderDetail> getOrder(String orderId) async {
    try {
      final orderRows = await _database.list(
        table: _orders,
        filters: {'id': orderId},
        limit: 1,
      );
      if (orderRows.isEmpty) {
        throw const Failure(message: 'Order not found.');
      }

      final itemRows = await _database.list(
        table: _orderItems,
        filters: {'order_id': orderId},
        orderBy: 'created_at',
      );
      final historyRows = await _database.list(
        table: _statusHistory,
        filters: {'order_id': orderId},
        orderBy: 'created_at',
        ascending: false,
      );
      final paymentRows = await _database.list(
        table: _payments,
        filters: {'order_id': orderId},
        limit: 1,
      );
      final shipmentRows = await _database.list(
        table: _shipments,
        filters: {'order_id': orderId},
        orderBy: 'created_at',
      );
      final shipments = shipmentRows.map(Shipment.fromMap).toList();
      final trackingEvents = await _loadTrackingEvents(
        shipments.map((s) => s.id).toList(),
      );

      return OrderDetail(
        order: Order.fromMap(orderRows.first),
        items: itemRows.map(OrderItem.fromMap).toList(),
        statusHistory: historyRows.map(OrderStatusEvent.fromMap).toList(),
        payment: paymentRows.isEmpty
            ? null
            : Payment.fromMap(paymentRows.first),
        shipments: shipments,
        trackingEvents: trackingEvents,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  Future<List<TrackingEvent>> _loadTrackingEvents(
    List<String> shipmentIds,
  ) async {
    if (shipmentIds.isEmpty) return const [];
    final rows = await _database.list(
      table: _trackingEvents,
      whereIn: {'shipment_id': shipmentIds},
      orderBy: 'event_time',
      ascending: false,
    );
    return rows.map(TrackingEvent.fromMap).toList();
  }

  @override
  Future<void> advanceStatus({
    required String orderId,
    required String status,
    String? notes,
  }) async {
    try {
      await _database.insert(
        table: _statusHistory,
        values: {
          'order_id': orderId,
          'status': status,
          'changed_by': await _requireProfileId(),
          'notes': ?notes,
        },
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> setPaymentStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final rows = await _database.list(
        table: _payments,
        filters: {'order_id': orderId},
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const Failure(message: 'No payment record for this order.');
      }
      await _database.update(
        table: _payments,
        values: {'status': status},
        matchColumn: 'id',
        matchValue: rows.first['id'] as Object,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) async {
    try {
      await _database.rpc(
        functionName: 'admin_cancel_order',
        params: {
          'p_order_id': orderId,
          if (reason != null && reason.trim().isNotEmpty)
            'p_reason': reason.trim(),
        },
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  Future<String> _requireProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) return result;
    throw const Failure(message: 'Please sign in.');
  }
}
