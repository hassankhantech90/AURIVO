import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/seller/data/repositories/supabase_seller_order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> summaryRow({String id = 'o1'}) => {
  'order_id': id,
  'order_number': 'AUR-$id',
  'status': 'confirmed',
  'currency': 'PKR',
  'placed_at': '2026-08-14T00:00:00Z',
  'item_count': 2,
  'seller_subtotal': 3000,
};

Map<String, dynamic> headerRow({String id = 'o1'}) => {
  'order_id': id,
  'order_number': 'AUR-$id',
  'status': 'confirmed',
  'currency': 'PKR',
  'placed_at': '2026-08-14T00:00:00Z',
  'shipping_address_snapshot': {'city': 'Lahore', 'line1': '1 Mall Rd'},
};

Map<String, dynamic> itemRow({String id = 'i1', num lineTotal = 1500}) => {
  'id': id,
  'order_id': 'o1',
  'product_id': 'p1',
  'product_variant_id': 'v1',
  'seller_id': 'sp1',
  'product_title_snapshot': 'Gold Ring',
  'sku_snapshot': 'SKU1',
  'unit_price': lineTotal,
  'quantity': 1,
  'line_total': lineTotal,
  'currency': 'PKR',
};

Map<String, dynamic> shipmentRow({String id = 's1', String status = 'pending'}) => {
  'id': id,
  'order_id': 'o1',
  'status': status,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  // rpc
  dynamic sellerOrdersResult;
  dynamic sellerOrderHeaderResult;
  String profileId = 'profile-1';

  // list
  List<Map<String, dynamic>> items = const [];
  List<Map<String, dynamic>> shipments = const [];

  // write capture
  Object? insertError;
  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    switch (functionName) {
      case 'seller_orders':
        return sellerOrdersResult ?? const [];
      case 'seller_order_header':
        return sellerOrderHeaderResult ?? const [];
      case 'current_profile_id':
        return profileId;
    }
    return null;
  }

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
    if (table == 'order_items') return items;
    if (table == 'shipments') return shipments;
    return const [];
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
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
    updated.add({'_match': '$matchColumn=$matchValue', ...values});
    return {'id': matchValue, 'order_id': 'o1', ...values};
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseSellerOrderRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseSellerOrderRepository(database: db);
  });

  group('getOrders', () {
    test('maps seller_orders() rows', () async {
      db.sellerOrdersResult = [summaryRow(id: 'o1'), summaryRow(id: 'o2')];
      final orders = await repo.getOrders();
      expect(orders.map((o) => o.orderId), ['o1', 'o2']);
      expect(orders.first.sellerSubtotal, 3000);
      expect(orders.first.itemCount, 2);
    });
  });

  group('getOrder', () {
    test('composes header + items + shipment', () async {
      db.sellerOrderHeaderResult = [headerRow()];
      db.items = [itemRow(id: 'i1', lineTotal: 1500), itemRow(id: 'i2', lineTotal: 1500)];
      db.shipments = [shipmentRow(status: 'shipped')];

      final detail = await repo.getOrder('o1');

      expect(detail.orderNumber, 'AUR-o1');
      expect(detail.shippingAddress['city'], 'Lahore');
      expect(detail.items, hasLength(2));
      expect(detail.sellerSubtotal, 3000);
      expect(detail.shipment!.status, 'shipped');
    });

    test('throws when the header is empty (not the seller\'s order)', () async {
      db.sellerOrderHeaderResult = const [];
      await expectLater(repo.getOrder('x'), throwsA(isA<Failure>()));
    });

    test('shipment is null when none exists', () async {
      db.sellerOrderHeaderResult = [headerRow()];
      db.items = [itemRow()];
      db.shipments = const [];
      final detail = await repo.getOrder('o1');
      expect(detail.shipment, isNull);
    });
  });

  group('advanceStatus', () {
    test('inserts a status-history row with resolved changed_by', () async {
      await repo.advanceStatus(orderId: 'o1', status: 'packed');
      final row = db.inserted.single;
      expect(row['_table'], 'order_status_history');
      expect(row['order_id'], 'o1');
      expect(row['status'], 'packed');
      expect(row['changed_by'], 'profile-1');
    });
  });

  group('saveShipment', () {
    test('inserts when no shipment exists, omitting blank fields', () async {
      db.shipments = const [];
      await repo.saveShipment(
        orderId: 'o1',
        status: 'shipped',
        courier: 'TCS',
        trackingNumber: '  ',
      );
      final row = db.inserted.single;
      expect(row['_table'], 'shipments');
      expect(row['order_id'], 'o1');
      expect(row['status'], 'shipped');
      expect(row['courier'], 'TCS');
      expect(row.containsKey('tracking_number'), isFalse); // blank omitted
    });

    test('updates by id when a shipment already exists', () async {
      db.shipments = [shipmentRow(id: 's1')];
      await repo.saveShipment(
        orderId: 'o1',
        status: 'in_transit',
        trackingNumber: 'TRK-9',
      );
      expect(db.inserted, isEmpty);
      final row = db.updated.single;
      expect(row['_match'], 'id=s1');
      expect(row['status'], 'in_transit');
      expect(row['tracking_number'], 'TRK-9');
    });

    test('maps a duplicate tracking number to a Failure', () async {
      db.shipments = const [];
      db.insertError = const ex.DatabaseException('dup', code: '23505');
      await expectLater(
        repo.saveShipment(orderId: 'o1', status: 'shipped', trackingNumber: 'X'),
        throwsA(
          predicate((e) => e is Failure && e.code == '23505'),
        ),
      );
    });
  });
}
