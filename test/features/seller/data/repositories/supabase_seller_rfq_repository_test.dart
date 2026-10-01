import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/seller/data/repositories/supabase_seller_rfq_repository.dart';
import 'package:aurivo/features/seller/domain/entities/quote_draft.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> rfqRow({String id = 'rfq-1', String? deletedAt}) => {
  'id': id,
  'buyer_profile_id': 'buyer-1',
  'seller_profile_id': 'sp-1',
  'quantity': 10,
  'status': 'open',
  'deleted_at': deletedAt,
};

Map<String, dynamic> quoteRow({String id = 'q-1', String? deletedAt}) => {
  'id': id,
  'rfq_id': 'rfq-1',
  'seller_profile_id': 'sp-1',
  'unit_price': 100,
  'total_price': 1000,
  'currency': 'PKR',
  'minimum_order_quantity': 10,
  'status': 'sent',
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? insertError;
  List<Map<String, dynamic>> Function(
    String table,
    Map<String, Object?> filters,
  )?
  onList;
  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<Map<String, Object?>> deleted = [];

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
    return {'id': 'q-new', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_match': '$matchColumn=$matchValue', ...values});
    return {...quoteRow(id: matchValue as String), ...values};
  }

  @override
  Future<void> delete({
    required String table,
    required String matchColumn,
    required Object matchValue,
  }) async {
    deleted.add({matchColumn: matchValue});
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async => functionName == 'my_seller_store' ? null : 'profile-1';
}

void _wireSeller(
  _StubDatabase db, {
  List<Map<String, dynamic>>? rfqs,
  List<Map<String, dynamic>>? quotes,
}) {
  db.onList = (table, filters) {
    switch (table) {
      case 'seller_profiles':
        return [
          {'id': 'sp-1', 'profile_id': 'profile-1'},
        ];
      case 'rfqs':
        return rfqs ?? [rfqRow()];
      case 'quotes':
        return quotes ?? const [];
      default:
        return const [];
    }
  };
}

void main() {
  late _StubDatabase db;
  late SupabaseSellerRfqRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseSellerRfqRepository(database: db);
  });

  test('getInboxRfqs filters by seller and hides soft-deleted', () async {
    Map<String, Object?>? seen;
    db.onList = (table, filters) {
      if (table == 'seller_profiles') {
        return [
          {'id': 'sp-1', 'profile_id': 'profile-1'},
        ];
      }
      seen = filters;
      return [
        rfqRow(id: 'a'),
        rfqRow(id: 'b', deletedAt: '2026-01-01T00:00:00Z'),
      ];
    };
    final rfqs = await repo.getInboxRfqs();
    expect(rfqs.map((r) => r.id), ['a']);
    expect(seen!['seller_profile_id'], 'sp-1');
  });

  test('getMyQuoteForRfq returns the seller quote or null', () async {
    _wireSeller(db, quotes: [quoteRow()]);
    expect((await repo.getMyQuoteForRfq('rfq-1'))!.id, 'q-1');

    _wireSeller(db, quotes: const []);
    expect(await repo.getMyQuoteForRfq('rfq-1'), isNull);
  });

  test('createQuote resolves seller_profile_id server-side (not UI)', () async {
    _wireSeller(db);
    await repo.createQuote(
      'rfq-1',
      const QuoteDraft(
        unitPrice: 100,
        totalPrice: 1000,
        minimumOrderQuantity: 10,
      ),
    );
    final values = db.inserted.single;
    expect(values['rfq_id'], 'rfq-1');
    expect(values['seller_profile_id'], 'sp-1'); // server-derived
    expect(values['unit_price'], 100);
    expect(values['total_price'], 1000);
    expect(values['minimum_order_quantity'], 10);
  });

  test(
    'createQuote maps duplicate (23505) to an already-quoted failure',
    () async {
      _wireSeller(db);
      db.insertError = const ex.DatabaseException('dup', code: '23505');
      await expectLater(
        repo.createQuote(
          'rfq-1',
          const QuoteDraft(unitPrice: 1, totalPrice: 1),
        ),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            contains('already quoted'),
          ),
        ),
      );
    },
  );

  test('createQuote maps total<unit*moq (23514) to a clear failure', () async {
    _wireSeller(db);
    db.insertError = const ex.DatabaseException('check', code: '23514');
    await expectLater(
      repo.createQuote(
        'rfq-1',
        const QuoteDraft(unitPrice: 100, totalPrice: 10),
      ),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          contains('at least unit price'),
        ),
      ),
    );
  });

  test('updateQuote writes by id; deleteQuote hard-deletes by id', () async {
    _wireSeller(db);
    await repo.updateQuote(
      'q-1',
      const QuoteDraft(unitPrice: 2, totalPrice: 20),
    );
    expect(db.updated.single['_match'], 'id=q-1');

    await repo.deleteQuote('q-1');
    expect(db.deleted.single['id'], 'q-1');
  });

  test('createQuote requires a seller store', () async {
    db.onList = (table, filters) => const [];
    await expectLater(
      repo.createQuote('rfq-1', const QuoteDraft(unitPrice: 1, totalPrice: 1)),
      throwsA(isA<Failure>()),
    );
  });
}
