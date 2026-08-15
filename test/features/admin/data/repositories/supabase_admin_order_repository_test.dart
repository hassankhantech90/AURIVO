import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/data/repositories/supabase_admin_order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> orderRow({String id = 'o1', String status = 'pending', String? deletedAt}) => {
  'id': id,
  'order_number': 'AUR-$id',
  'profile_id': 'buyer-1',
  'status': status,
  'payment_status': 'pending',
  'currency': 'PKR',
  'grand_total': 1000,
  'shipping_address_snapshot': {'city': 'Lahore'},
  'billing_address_snapshot': {'city': 'Lahore'},
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Map<String, List<Map<String, dynamic>>> tables = {};
  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<Map<String, dynamic>> rpcCalls = [];
  String profileId = 'admin-profile';

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
    var rows = tables[table] ?? const [];
    for (final f in filters.entries) {
      rows = rows.where((r) => r[f.key] == f.value).toList();
    }
    return rows;
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    inserted.add({'_table': table, ...values});
    return {'id': 'new', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_table': table, '_match': '$matchColumn=$matchValue', ...values});
    return {'id': matchValue, ...values};
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    if (functionName == 'current_profile_id') return profileId;
    rpcCalls.add({'fn': functionName, ...params});
    return null;
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseAdminOrderRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseAdminOrderRepository(database: db);
  });

  test('listOrders filters status and excludes soft-deleted', () async {
    db.tables = {
      'orders': [
        orderRow(id: 'a', status: 'confirmed'),
        orderRow(id: 'b', status: 'confirmed', deletedAt: '2026-08-14T00:00:00Z'),
      ],
    };
    final orders = await repo.listOrders(status: 'confirmed');
    expect(orders.map((o) => o.id), ['a']);
  });

  test('getOrder composes header, items, payment and shipments', () async {
    db.tables = {
      'orders': [orderRow()],
      'order_items': [
        {
          'id': 'i1',
          'order_id': 'o1',
          'product_id': 'p1',
          'product_variant_id': 'v1',
          'seller_id': 's1',
          'product_title_snapshot': 'Ring',
          'sku_snapshot': 'SKU',
          'unit_price': 1000,
          'quantity': 1,
          'line_total': 1000,
        },
      ],
      'payments': [
        {
          'id': 'pay1',
          'order_id': 'o1',
          'provider': 'manual',
          'method': 'cash_on_delivery',
          'amount': 1000,
          'status': 'pending',
        },
      ],
      'shipments': [
        {'id': 'sh1', 'order_id': 'o1', 'status': 'pending'},
      ],
    };
    final detail = await repo.getOrder('o1');
    expect(detail.order.orderNumber, 'AUR-o1');
    expect(detail.items, hasLength(1));
    expect(detail.payment!.status, 'pending');
    expect(detail.shipments.single.id, 'sh1');
  });

  test('getOrder throws when the order is missing', () async {
    db.tables = {'orders': const []};
    await expectLater(repo.getOrder('x'), throwsA(isA<Failure>()));
  });

  test('advanceStatus inserts an audited history row', () async {
    await repo.advanceStatus(orderId: 'o1', status: 'processing', notes: 'go');
    final row = db.inserted.single;
    expect(row['_table'], 'order_status_history');
    expect(row['order_id'], 'o1');
    expect(row['status'], 'processing');
    expect(row['changed_by'], 'admin-profile');
    expect(row['notes'], 'go');
  });

  test('setPaymentStatus updates the payment record', () async {
    db.tables = {
      'payments': [
        {'id': 'pay1', 'order_id': 'o1', 'status': 'pending'},
      ],
    };
    await repo.setPaymentStatus(orderId: 'o1', status: 'paid');
    final row = db.updated.single;
    expect(row['_table'], 'payments');
    expect(row['_match'], 'id=pay1');
    expect(row['status'], 'paid');
  });

  test('setPaymentStatus throws when there is no payment', () async {
    db.tables = {'payments': const []};
    await expectLater(
      repo.setPaymentStatus(orderId: 'o1', status: 'paid'),
      throwsA(isA<Failure>()),
    );
  });

  test('cancelOrder calls the admin_cancel_order RPC', () async {
    await repo.cancelOrder(orderId: 'o1', reason: 'fraud');
    final call = db.rpcCalls.single;
    expect(call['fn'], 'admin_cancel_order');
    expect(call['p_order_id'], 'o1');
    expect(call['p_reason'], 'fraud');
  });
}
