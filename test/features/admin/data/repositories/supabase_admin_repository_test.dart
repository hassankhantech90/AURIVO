import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/data/repositories/supabase_admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sellerRow({String id = 'sp1'}) => {
  'id': id,
  'profile_id': 'p1',
  'store_name': 'Zainab Jewellers',
  'slug': 'zainab',
  'verification_status': 'pending',
};

Map<String, dynamic> productRow({String id = 'pr1'}) => {
  'id': id,
  'seller_id': 'sp1',
  'title': 'Gold Ring',
  'slug': 'gold-ring',
  'jewellery_type': 'ring',
  'currency': 'PKR',
  'base_price': 1000,
  'status': 'pending',
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? rpcResult;
  Object? listError;
  List<Map<String, dynamic>> Function(String table, Map<String, Object?> filters)?
  onList;
  final List<Map<String, dynamic>> updates = [];

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async => rpcResult;

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
    if (listError != null) throw listError!;
    return onList?.call(table, filters) ?? const [];
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updates.add({'_table': table, '_match': '$matchColumn=$matchValue', ...values});
    return {'id': matchValue, ...values};
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseAdminRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseAdminRepository(database: db);
  });

  group('isAdmin', () {
    test('true when has_role returns true', () async {
      db.rpcResult = true;
      expect(await repo.isAdmin(), isTrue);
    });
    test('false otherwise', () async {
      db.rpcResult = false;
      expect(await repo.isAdmin(), isFalse);
    });
  });

  group('pending queues', () {
    test('getPendingSellers filters on pending verification', () async {
      db.onList = (table, filters) {
        expect(table, 'seller_profiles');
        expect(filters['verification_status'], 'pending');
        return [sellerRow(id: 'a'), sellerRow(id: 'b')];
      };
      final sellers = await repo.getPendingSellers();
      expect(sellers.map((s) => s.id), ['a', 'b']);
    });

    test('getPendingProducts filters on pending status', () async {
      db.onList = (table, filters) {
        expect(table, 'products');
        expect(filters['status'], 'pending');
        return [productRow(id: 'x')];
      };
      final products = await repo.getPendingProducts();
      expect(products.single.id, 'x');
      expect(products.single.status, 'pending');
    });
  });

  group('moderation writes', () {
    test('setSellerVerification updates the row', () async {
      await repo.setSellerVerification(sellerId: 'sp1', status: 'verified');
      final row = db.updates.single;
      expect(row['_table'], 'seller_profiles');
      expect(row['_match'], 'id=sp1');
      expect(row['verification_status'], 'verified');
    });

    test('setProductStatus updates the row', () async {
      await repo.setProductStatus(productId: 'pr1', status: 'approved');
      final row = db.updates.single;
      expect(row['_table'], 'products');
      expect(row['_match'], 'id=pr1');
      expect(row['status'], 'approved');
    });

    test('maps a permission error (42501) to a Failure', () async {
      db.listError = const ex.DatabaseException('denied', code: '42501');
      await expectLater(
        repo.getPendingProducts(),
        throwsA(predicate((e) => e is Failure && e.code == '42501')),
      );
    });
  });
}
