import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/reviews/data/repositories/supabase_review_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> reviewRow({
  String id = 'r1',
  String profileId = 'profile-1',
  String productId = 'prod-1',
  int rating = 5,
  String status = 'approved',
}) => {
  'id': id,
  'profile_id': profileId,
  'product_id': productId,
  'rating': rating,
  'status': status,
  'verified_purchase': false,
  'helpful_count': 0,
  'created_at': '2026-01-01T00:00:00Z',
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? rpcResult = 'profile-1';
  Object? insertError;
  List<Map<String, dynamic>> Function(Map<String, Object?> filters)? onList;

  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<Map<String, Object?>> deleted = [];

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
    return onList?.call(filters) ?? const [];
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (insertError != null) throw insertError!;
    inserted.add(values);
    return {'id': 'r-new', 'created_at': '2026-01-01T00:00:00Z', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({...values, '_match': '$matchColumn=$matchValue'});
    return {
      'id': matchValue,
      'profile_id': 'profile-1',
      'product_id': 'prod-1',
      'status': 'pending',
      ...values,
    };
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
  }) async {
    return rpcResult;
  }
}

void main() {
  late _StubDatabase db;
  late SupabaseReviewRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseReviewRepository(database: db);
  });

  test('getApprovedReviews filters by product and approved status', () async {
    Map<String, Object?>? seen;
    db.onList = (filters) {
      seen = filters;
      return [reviewRow(id: 'a'), reviewRow(id: 'b')];
    };

    final reviews = await repo.getApprovedReviews('prod-1');

    expect(reviews, hasLength(2));
    expect(seen!['product_id'], 'prod-1');
    expect(seen!['status'], 'approved');
  });

  test('getMyReviewForProduct returns null when not authenticated', () async {
    db.rpcResult = null;
    expect(await repo.getMyReviewForProduct('prod-1'), isNull);
  });

  test('getMyReviewForProduct returns the row when present', () async {
    db.onList = (filters) => [reviewRow(status: 'pending')];
    final mine = await repo.getMyReviewForProduct('prod-1');
    expect(mine, isNotNull);
    expect(mine!.isPending, isTrue);
  });

  test(
    'createReview sends only allowed columns with resolved profile',
    () async {
      await repo.createReview(
        productId: 'prod-1',
        orderItemId: 'oi-1',
        rating: 4,
        title: '  Nice  ',
        comment: '   ',
      );

      final values = db.inserted.single;
      expect(values['profile_id'], 'profile-1');
      expect(values['product_id'], 'prod-1');
      expect(values['order_item_id'], 'oi-1');
      expect(values['rating'], 4);
      expect(values['title'], 'Nice'); // trimmed
      expect(values.containsKey('comment'), isFalse); // blank dropped
      // Never client-controlled:
      expect(values.containsKey('status'), isFalse);
      expect(values.containsKey('verified_purchase'), isFalse);
      expect(values.containsKey('helpful_count'), isFalse);
    },
  );

  test('createReview requires authentication', () async {
    db.rpcResult = null;
    await expectLater(
      repo.createReview(productId: 'prod-1', rating: 5),
      throwsA(isA<Failure>()),
    );
  });

  test('createReview maps a duplicate (23505) to a clear failure', () async {
    db.insertError = const ex.DatabaseException('dup', code: '23505');
    await expectLater(
      repo.createReview(productId: 'prod-1', rating: 5),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          'You have already reviewed this product.',
        ),
      ),
    );
  });

  test('updateReview sends rating/title/comment matched by id', () async {
    await repo.updateReview(
      reviewId: 'r1',
      rating: 2,
      title: 'Meh',
      comment: '',
    );
    final values = db.updated.single;
    expect(values['rating'], 2);
    expect(values['title'], 'Meh');
    expect(values['comment'], isNull); // blank clears
    expect(values['_match'], 'id=r1');
    expect(values.containsKey('status'), isFalse);
    expect(values.containsKey('order_item_id'), isFalse);
  });

  test('deleteReview deletes by id', () async {
    await repo.deleteReview('r1');
    expect(db.deleted.single['id'], 'r1');
  });
}
