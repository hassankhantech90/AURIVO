import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/seller/data/repositories/supabase_seller_variant_repository.dart';
import 'package:aurivo/features/seller/domain/entities/seller_variant.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> variantRow({String id = 'v1', String? deletedAt}) => {
  'id': id,
  'product_id': 'prod-1',
  'sku': 'SKU-$id',
  'price': 1000,
  'currency': 'PKR',
  'stock_quantity': 5,
  'reserved_quantity': 1,
  'low_stock_threshold': 2,
  'is_active': true,
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? insertError;
  List<Map<String, dynamic>> Function()? onList;
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
  }) async => onList?.call() ?? const [];

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add(values);
    return {'id': 'v-new', 'reserved_quantity': 0, ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_match': '$matchColumn=$matchValue', ...values});
    return {...variantRow(id: matchValue as String), ...values};
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async => null;
}

void main() {
  late _StubDatabase db;
  late SupabaseSellerVariantRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseSellerVariantRepository(database: db);
  });

  test('getVariants hides soft-deleted', () async {
    db.onList = () => [
      variantRow(id: 'a'),
      variantRow(id: 'b', deletedAt: '2026-01-01T00:00:00Z'),
    ];
    final variants = await repo.getVariants('prod-1');
    expect(variants.map((v) => v.id), ['a']);
    expect(variants.single.availableQuantity, 4); // 5 stock - 1 reserved
  });

  test(
    'createVariant sends product_id + editable columns (no reserved)',
    () async {
      await repo.createVariant(
        'prod-1',
        const VariantDraft(sku: 'SKU-1', price: 1500, stockQuantity: 10),
      );
      final values = db.inserted.single;
      expect(values['product_id'], 'prod-1');
      expect(values['sku'], 'SKU-1');
      expect(values['price'], 1500);
      expect(values['stock_quantity'], 10);
      expect(values.containsKey('reserved_quantity'), isFalse);
    },
  );

  test('createVariant maps a duplicate SKU (23505) to a failure', () async {
    db.insertError = const ex.DatabaseException('dup', code: '23505');
    await expectLater(
      repo.createVariant('prod-1', const VariantDraft(sku: 'X', price: 1)),
      throwsA(isA<Failure>()),
    );
  });

  test('softDelete sets deleted_at by id', () async {
    await repo.softDelete('v1');
    expect(db.updated.single['_match'], 'id=v1');
    expect(db.updated.single['deleted_at'], isNotNull);
  });
}
