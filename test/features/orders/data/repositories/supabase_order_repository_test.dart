import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> orderRow({String id = 'o1'}) => {
  'id': id,
  'order_number': 'AUR260811000001',
  'profile_id': 'p1',
  'address_id': 'a1',
  'status': 'pending',
  'payment_status': 'pending',
  'currency': 'PKR',
  'subtotal': 1500,
  'grand_total': 1500,
  'shipping_address_snapshot': {'city': 'Karachi'},
  'billing_address_snapshot': {'city': 'Karachi'},
  'placed_at': '2026-08-11T10:00:00Z',
};

Map<String, dynamic> itemRow() => {
  'id': 'i1',
  'order_id': 'o1',
  'product_id': 'prod-1',
  'product_variant_id': 'var-1',
  'seller_id': 'seller-1',
  'product_title_snapshot': 'Gold Ring',
  'sku_snapshot': 'SKU-1',
  'unit_price': 750,
  'quantity': 2,
  'line_total': 1500,
  'currency': 'PKR',
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? throwError;
  final List<Map<String, dynamic>> rpcCalls = [];
  List<Map<String, dynamic>> Function(
    String table,
    Map<String, Object?> filters,
    Map<String, List<Object>> whereIn,
  )?
  onList;

  @override
  Future<List<Map<String, dynamic>>> list({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
    Map<String, List<Object>> whereIn = const {},
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    if (throwError != null) throw throwError!;
    return onList?.call(table, filters, whereIn) ?? const [];
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    if (throwError != null) throw throwError!;
    rpcCalls.add({'fn': functionName, ...params});
    return null;
  }
}

void main() {
  late _StubDatabase db;
  SupabaseOrderRepository build() => SupabaseOrderRepository(database: db);

  setUp(() => db = _StubDatabase());

  test('getOrders returns parsed orders', () async {
    db.onList = (table, filters, whereIn) =>
        table == 'orders' ? [orderRow()] : const [];

    final orders = await build().getOrders();

    expect(orders.length, 1);
    expect(orders.first.orderNumber, 'AUR260811000001');
  });

  test(
    'getOrder assembles the full detail incl. tracking via whereIn',
    () async {
      var trackingQueriedWith = <Object>[];
      db.onList = (table, filters, whereIn) {
        switch (table) {
          case 'orders':
            return [orderRow()];
          case 'order_items':
            return [itemRow()];
          case 'order_status_history':
            return [
              {
                'id': 'e1',
                'order_id': 'o1',
                'status': 'pending',
                'notes': 'Order placed.',
                'created_at': '2026-08-11T10:00:00Z',
              },
            ];
          case 'payments':
            return [
              {
                'id': 'pay-1',
                'order_id': 'o1',
                'provider': 'manual',
                'method': 'cash_on_delivery',
                'status': 'pending',
                'amount': 1500,
                'currency': 'PKR',
              },
            ];
          case 'shipments':
            return [
              {
                'id': 's1',
                'order_id': 'o1',
                'courier': 'TCS',
                'tracking_number': 'TRK1',
                'status': 'shipped',
              },
            ];
          case 'tracking_events':
            trackingQueriedWith = whereIn['shipment_id'] ?? const [];
            return [
              {
                'id': 't1',
                'shipment_id': 's1',
                'status': 'in_transit',
                'event_time': '2026-08-12T09:00:00Z',
              },
            ];
          default:
            return const [];
        }
      };

      final detail = await build().getOrder('o1');

      expect(detail.order.id, 'o1');
      expect(detail.items.length, 1);
      expect(detail.statusHistory.length, 1);
      expect(detail.payment, isNotNull);
      expect(detail.shipments.length, 1);
      expect(detail.trackingEvents.length, 1);
      expect(trackingQueriedWith, contains('s1'));
      expect(detail.eventsForShipment('s1').length, 1);
    },
  );

  test('getOrder without shipments skips the tracking query', () async {
    var trackingQueried = false;
    db.onList = (table, filters, whereIn) {
      if (table == 'orders') return [orderRow()];
      if (table == 'tracking_events') {
        trackingQueried = true;
        return const [];
      }
      return const [];
    };

    final detail = await build().getOrder('o1');

    expect(detail.shipments, isEmpty);
    expect(detail.trackingEvents, isEmpty);
    expect(trackingQueried, isFalse);
  });

  test('getOrder throws a Failure when the order is not found', () async {
    db.onList = (table, filters, whereIn) => const [];
    await expectLater(build().getOrder('missing'), throwsA(isA<Failure>()));
  });

  test('cancelOrder calls cancel_order with id and reason', () async {
    await build().cancelOrder(orderId: 'o1', reason: 'changed mind');

    final call = db.rpcCalls.single;
    expect(call['fn'], 'cancel_order');
    expect(call['p_order_id'], 'o1');
    expect(call['p_reason'], 'changed mind');
  });

  test('cancelOrder surfaces a raised P0001 message as a Failure', () async {
    db.throwError = const ex.DatabaseException(
      'Order can no longer be cancelled.',
      code: 'P0001',
    );
    await expectLater(
      build().cancelOrder(orderId: 'o1'),
      throwsA(
        predicate(
          (e) =>
              e is Failure && e.message == 'Order can no longer be cancelled.',
        ),
      ),
    );
  });

  test('never surfaces a raw Supabase exception', () async {
    db.throwError = const ex.NetworkException('offline');
    await expectLater(
      build().getOrders(),
      throwsA(predicate((e) => e is Failure && e is! ex.AppSupabaseException)),
    );
  });
}
