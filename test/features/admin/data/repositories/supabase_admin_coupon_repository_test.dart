import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/data/repositories/supabase_admin_coupon_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> couponRow({String id = 'cp1', String? deletedAt}) => {
  'id': id,
  'code': 'SAVE10',
  'name': 'Save 10',
  'discount_type': 'percentage',
  'discount_value': 10,
  'minimum_order_amount': 0,
  'per_user_limit': 1,
  'used_count': 3,
  'status': 'active',
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? insertError;
  List<Map<String, dynamic>> Function(String table, Map<String, Object?> filters)?
  onList;
  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];

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
  }) async => onList?.call(table, filters) ?? const [];

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add(values);
    return {...couponRow(), ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_match': '$matchColumn=$matchValue', ...values});
    return {...couponRow(id: matchValue as String), ...values};
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseAdminCouponRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseAdminCouponRepository(database: db);
  });

  test('listCoupons excludes soft-deleted rows', () async {
    db.onList = (table, filters) => [
      couponRow(id: 'live'),
      couponRow(id: 'dead', deletedAt: '2026-08-14T00:00:00Z'),
    ];
    final coupons = await repo.listCoupons();
    expect(coupons.map((c) => c.id), ['live']);
    expect(coupons.single.usedCount, 3);
  });

  test('createCoupon uppercases the code and passes fields', () async {
    await repo.createCoupon(
      code: ' save10 ',
      name: 'Save 10',
      discountType: 'percentage',
      discountValue: 10,
      usageLimit: 100,
    );
    final row = db.inserted.single;
    expect(row['code'], 'SAVE10');
    expect(row['discount_type'], 'percentage');
    expect(row['usage_limit'], 100);
    expect(row.containsKey('deleted_at'), isFalse);
  });

  test('updateCoupon clears usage limit / max discount when asked', () async {
    await repo.updateCoupon(
      id: 'cp1',
      clearUsageLimit: true,
      clearMaximumDiscount: true,
    );
    final row = db.updated.single;
    expect(row.containsKey('usage_limit'), isTrue);
    expect(row['usage_limit'], isNull);
    expect(row['maximum_discount_amount'], isNull);
    expect(row.containsKey('used_count'), isFalse); // never written
  });

  test('setStatus updates only status', () async {
    await repo.setStatus(id: 'cp1', status: 'paused');
    expect(db.updated.single['status'], 'paused');
  });

  test('deleteCoupon archives and soft-deletes', () async {
    await repo.deleteCoupon('cp1');
    final row = db.updated.single;
    expect(row['deleted_at'], isNotNull);
    expect(row['status'], 'archived');
  });

  test('listRedemptions filters by coupon', () async {
    db.onList = (table, filters) {
      expect(table, 'coupon_redemptions');
      expect(filters['coupon_id'], 'cp1');
      return [
        {
          'id': 'r1',
          'coupon_id': 'cp1',
          'profile_id': 'p1',
          'discount_amount': 50,
        },
      ];
    };
    final reds = await repo.listRedemptions('cp1');
    expect(reds.single.discountAmount, 50);
  });

  test('maps duplicate code (23505) to a Failure', () async {
    db.insertError = const ex.DatabaseException('dup', code: '23505');
    await expectLater(
      repo.createCoupon(
        code: 'SAVE10',
        name: 'x',
        discountType: 'percentage',
        discountValue: 10,
      ),
      throwsA(predicate((e) => e is Failure && e.code == '23505')),
    );
  });
}
