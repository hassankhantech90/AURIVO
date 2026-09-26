import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/coupons/data/repositories/supabase_coupon_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> redemptionRow() => {
  'id': 'red-1',
  'coupon_id': 'c1',
  'profile_id': 'profile-1',
  'order_id': 'o1',
  'discount_amount': 250,
  'currency': 'PKR',
  'redeemed_at': '2026-01-01T00:00:00Z',
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? rpcResult;
  Object? rpcError;
  Map<String, dynamic>? rpcParams;
  String? rpcName;
  List<Map<String, dynamic>> Function()? onList;

  @override
  Future<List<Map<String, dynamic>>> list({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
    Map<String, List<Object>> whereIn = const {},
    String? ilikeColumn,
    String? ilikeQuery,
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    return onList?.call() ?? const [];
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    rpcName = functionName;
    rpcParams = params;
    if (rpcError != null) throw rpcError!;
    return rpcResult;
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseCouponRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseCouponRepository(database: db);
  });

  test('getActiveCoupons maps rows from the coupons table', () async {
    db.onList = () => [
      {
        'id': 'c1',
        'code': 'SAVE10',
        'name': '10% off',
        'discount_type': 'percentage',
        'discount_value': 10,
        'minimum_order_amount': 1000,
        'status': 'active',
      },
    ];

    final coupons = await repo.getActiveCoupons();

    expect(coupons, hasLength(1));
    expect(coupons.single.code, 'SAVE10');
    expect(coupons.single.isPercentage, isTrue);
  });

  test('redeem sends ONLY p_code and p_order_id (no amounts)', () async {
    db.rpcResult = redemptionRow();

    final redemption = await repo.redeem(code: '  SAVE10 ', orderId: 'o1');

    expect(db.rpcName, 'redeem_coupon');
    expect(db.rpcParams!.keys.toSet(), {'p_code', 'p_order_id'});
    expect(db.rpcParams!['p_code'], 'SAVE10'); // trimmed
    expect(db.rpcParams!['p_order_id'], 'o1');
    expect(redemption.discountAmount, 250);
    expect(redemption.orderId, 'o1');
  });

  test('redeem accepts a single-row list result', () async {
    db.rpcResult = [redemptionRow()];
    final redemption = await repo.redeem(code: 'SAVE10', orderId: 'o1');
    expect(redemption.id, 'red-1');
  });

  test('redeem preserves a P0001 server message', () async {
    db.rpcError = const ex.DatabaseException(
      'Coupon usage limit reached.',
      code: 'P0001',
    );
    await expectLater(
      repo.redeem(code: 'X', orderId: 'o1'),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          'Coupon usage limit reached.',
        ),
      ),
    );
  });

  test(
    'redeem maps a duplicate (23505) to an already-applied message',
    () async {
      db.rpcError = const ex.DatabaseException('dup', code: '23505');
      await expectLater(
        repo.redeem(code: 'X', orderId: 'o1'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'That coupon is already applied to this order.',
          ),
        ),
      );
    },
  );
}
