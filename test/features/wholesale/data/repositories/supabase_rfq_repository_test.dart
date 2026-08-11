import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/wholesale/data/repositories/supabase_rfq_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> rfqRow({
  String id = 'rfq-1',
  String buyer = 'profile-1',
  int quantity = 10,
  String status = 'open',
}) => {
  'id': id,
  'buyer_profile_id': buyer,
  'quantity': quantity,
  'currency': 'PKR',
  'status': status,
  'created_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> quoteRow({String id = 'q-1'}) => {
  'id': id,
  'rfq_id': 'rfq-1',
  'seller_profile_id': 's1',
  'unit_price': 100,
  'total_price': 1000,
  'currency': 'PKR',
  'minimum_order_quantity': 10,
  'status': 'sent',
  'created_at': '2026-01-02T00:00:00Z',
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? rpcResult = 'profile-1';
  Object? insertError;
  List<Map<String, dynamic>> Function(
    String table,
    Map<String, Object?> filters,
  )?
  onList;

  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];

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
    return onList?.call(table, filters) ?? const [];
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add(values);
    return {'id': 'rfq-new', 'created_at': '2026-01-01T00:00:00Z', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({...values, '_match': '$matchColumn=$matchValue'});
    return {...rfqRow(id: matchValue as String), ...values};
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    return rpcResult;
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseRfqRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseRfqRepository(database: db);
  });

  test(
    'createRfq sets buyer_profile_id from current_profile_id (not UI)',
    () async {
      await repo.createRfq(
        quantity: 25,
        productId: 'prod-1',
        sellerProfileId: 's1',
        targetPrice: 900,
        message: '  bulk order  ',
      );

      final values = db.inserted.single;
      expect(values['buyer_profile_id'], 'profile-1'); // server-derived
      expect(values['quantity'], 25);
      expect(values['product_id'], 'prod-1');
      expect(values['seller_profile_id'], 's1');
      expect(values['target_price'], 900);
      expect(values['message'], 'bulk order'); // trimmed
      expect(values['status'], isNull); // server default 'open'
    },
  );

  test('createRfq omits blank optional fields', () async {
    await repo.createRfq(quantity: 5, message: '   ');
    final values = db.inserted.single;
    expect(values.containsKey('product_id'), isFalse);
    expect(values.containsKey('seller_profile_id'), isFalse);
    expect(values.containsKey('target_price'), isFalse);
    expect(values.containsKey('message'), isFalse);
  });

  test('createRfq requires authentication', () async {
    db.rpcResult = null;
    await expectLater(repo.createRfq(quantity: 5), throwsA(isA<Failure>()));
  });

  test(
    'createRfq maps a check violation (bad quantity) to a Failure',
    () async {
      db.insertError = const ex.DatabaseException('bad', code: '23514');
      await expectLater(
        repo.createRfq(quantity: 0),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Please enter a valid quantity and price.',
          ),
        ),
      );
    },
  );

  test('getMyRfqs filters by the resolved buyer profile', () async {
    Map<String, Object?>? seen;
    db.onList = (table, filters) {
      seen = filters;
      return [rfqRow(id: 'a'), rfqRow(id: 'b')];
    };

    final rfqs = await repo.getMyRfqs();

    expect(rfqs, hasLength(2));
    expect(seen!['buyer_profile_id'], 'profile-1');
  });

  test('getRfq returns the rfq with its quotes', () async {
    db.onList = (table, filters) =>
        table == 'rfqs' ? [rfqRow()] : [quoteRow(id: 'x'), quoteRow(id: 'y')];

    final detail = await repo.getRfq('rfq-1');

    expect(detail.rfq.id, 'rfq-1');
    expect(detail.quotes, hasLength(2));
    expect(detail.hasQuotes, isTrue);
  });

  test('getRfq throws a Failure when not found', () async {
    db.onList = (table, filters) => const [];
    await expectLater(repo.getRfq('missing'), throwsA(isA<Failure>()));
  });

  test('cancelRfq updates status to cancelled by id', () async {
    final rfq = await repo.cancelRfq('rfq-1');
    final values = db.updated.single;
    expect(values['status'], 'cancelled');
    expect(values['_match'], 'id=rfq-1');
    expect(rfq.status, 'cancelled');
  });
}
