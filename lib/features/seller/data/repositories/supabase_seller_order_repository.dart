import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../../orders/domain/entities/order_item.dart';
import '../../../orders/domain/entities/shipment.dart';
import '../../domain/entities/seller_order_detail.dart';
import '../../domain/entities/seller_order_summary.dart';
import '../../domain/repositories/seller_order_repository.dart';
import '../seller_order_failure_mapper.dart';

/// Supabase-backed [SellerOrderRepository].
///
/// Order headers come from the `seller_orders()` / `seller_order_header()`
/// SECURITY DEFINER RPCs; items and shipments are read through the existing
/// seller-scoped RLS. Writes never trust an order/seller id from the UI —
/// ownership is enforced by the status-history/shipments RLS policies.
class SupabaseSellerOrderRepository implements SellerOrderRepository {
  SupabaseSellerOrderRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _orderItemsTable = 'order_items';
  static const String _shipmentsTable = 'shipments';
  static const String _statusHistoryTable = 'order_status_history';

  @override
  Future<List<SellerOrderSummary>> getOrders() async {
    try {
      final result = await _database.rpc(functionName: 'seller_orders');
      final rows = (result as List<dynamic>).cast<Map<String, dynamic>>();
      return rows.map(SellerOrderSummary.fromMap).toList();
    } catch (error) {
      throw SellerOrderFailureMapper.map(error);
    }
  }

  @override
  Future<SellerOrderDetail> getOrder(String orderId) async {
    try {
      final headerResult = await _database.rpc(
        functionName: 'seller_order_header',
        params: {'p_order_id': orderId},
      );
      final headerRows = (headerResult as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (headerRows.isEmpty) {
        throw const Failure(message: 'Order not found.');
      }

      // RLS scopes both reads to this seller's own rows for the order.
      final itemRows = await _database.list(
        table: _orderItemsTable,
        filters: {'order_id': orderId},
        orderBy: 'created_at',
      );
      final shipmentRows = await _database.list(
        table: _shipmentsTable,
        filters: {'order_id': orderId},
        orderBy: 'created_at',
        ascending: false,
        limit: 1,
      );

      return SellerOrderDetail.fromParts(
        header: headerRows.first,
        items: itemRows.map(OrderItem.fromMap).toList(),
        shipment: shipmentRows.isEmpty
            ? null
            : Shipment.fromMap(shipmentRows.first),
      );
    } catch (error) {
      throw SellerOrderFailureMapper.map(error);
    }
  }

  @override
  Future<void> advanceStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      // Fire-and-forget: sellers can INSERT into order_status_history but have
      // no SELECT policy on it, so a read-back (`.select().single()`) would
      // roll the insert back. The updated status is re-read via the header RPC.
      await _database.insertVoid(
        table: _statusHistoryTable,
        values: {
          'order_id': orderId,
          'status': status,
          'changed_by': await _requireProfileId(),
        },
      );
    } catch (error) {
      throw SellerOrderFailureMapper.map(error);
    }
  }

  @override
  Future<Shipment> saveShipment({
    required String orderId,
    required String status,
    String? courier,
    String? trackingNumber,
    String? trackingUrl,
  }) async {
    try {
      final values = <String, dynamic>{
        'status': status,
        'courier': ?_clean(courier),
        'tracking_number': ?_clean(trackingNumber),
        'tracking_url': ?_clean(trackingUrl),
      };

      final existing = await _database.list(
        table: _shipmentsTable,
        filters: {'order_id': orderId},
        limit: 1,
      );

      final row = existing.isEmpty
          ? await _database.insert(
              table: _shipmentsTable,
              values: {'order_id': orderId, ...values},
            )
          : await _database.update(
              table: _shipmentsTable,
              values: values,
              matchColumn: 'id',
              matchValue: existing.first['id'] as Object,
            );
      return Shipment.fromMap(row);
    } catch (error) {
      throw SellerOrderFailureMapper.map(error);
    }
  }

  String? _clean(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<String> _requireProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) return result;
    throw const Failure(message: 'Please sign in to manage your orders.');
  }
}
