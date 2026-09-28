import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/seller/data/repositories/supabase_seller_tier_repository.dart';
import 'package:aurivo/features/seller/domain/entities/price_tier_draft.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> tierRow({String id = 't1', int minQuantity = 10}) => {
  'id': id,
  'product_id': 'prod-1',
  'min_quantity': minQuantity,
  'unit_price': 82000,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? insertError;
  List<Map<String, dynamic>> Function()? onList;
  String? lastOrderBy;
  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<String> deleted = [];

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
    lastOrderBy = orderBy;
    return onList?.call() ?? const [];
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add(values);
    return {'id': 't-new', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_match': '$matchColumn=$matchValue', ...values});
    return {...tierRow(id: matchValue as String), ...values};
  }

  @override
  Future<void> delete({
    required String table,
    required String matchColumn,
    required Object matchValue,
  }) async {
    deleted.add('$matchColumn=$matchValue');
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseSellerTierRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseSellerTierRepository(database: db);
  });

  test('getTiers maps rows and orders by min_quantity', () async {
    db.onList = () => [tierRow(id: 'a', minQuantity: 5), tierRow(id: 'b')];
    final tiers = await repo.getTiers('prod-1');
    expect(tiers.map((t) => t.id), ['a', 'b']);
    expect(tiers.first.minQuantity, 5);
    expect(db.lastOrderBy, 'min_quantity');
  });

  test('createTier sends product_id + quantity + unit price', () async {
    await repo.createTier(
      'prod-1',
      const PriceTierDraft(minQuantity: 10, unitPrice: 82000),
    );
    final values = db.inserted.single;
    expect(values['product_id'], 'prod-1');
    expect(values['min_quantity'], 10);
    expect(values['unit_price'], 82000);
  });

  test('createTier maps a duplicate quantity (23505) to a failure', () async {
    db.insertError = const ex.DatabaseException('dup', code: '23505');
    await expectLater(
      repo.createTier(
        'prod-1',
        const PriceTierDraft(minQuantity: 10, unitPrice: 1),
      ),
      throwsA(isA<Failure>()),
    );
  });

  test('updateTier matches by id', () async {
    await repo.updateTier(
      't1',
      const PriceTierDraft(minQuantity: 20, unitPrice: 75000),
    );
    expect(db.updated.single['_match'], 'id=t1');
    expect(db.updated.single['min_quantity'], 20);
  });

  test('deleteTier hard-deletes by id', () async {
    await repo.deleteTier('t1');
    expect(db.deleted.single, 'id=t1');
  });
}
