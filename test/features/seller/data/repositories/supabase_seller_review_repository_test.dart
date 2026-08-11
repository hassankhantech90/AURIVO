import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/seller/data/repositories/supabase_seller_review_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> reviewRow({
  String id = 'r1',
  int rating = 5,
  String status = 'approved',
}) => {
  'id': id,
  'profile_id': 'profile-1',
  'seller_profile_id': 's1',
  'rating': rating,
  'status': status,
  'verified_purchase': false,
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
      'seller_profile_id': 's1',
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
  late SupabaseSellerReviewRepository repo;

  setUp(() {
    db = _StubDatabase();
    repo = SupabaseSellerReviewRepository(database: db);
  });

  test('getApprovedReviews filters by seller and approved status', () async {
    Map<String, Object?>? seen;
    db.onList = (filters) {
      seen = filters;
      return [reviewRow(id: 'a'), reviewRow(id: 'b')];
    };

    final reviews = await repo.getApprovedReviews('s1');

    expect(reviews, hasLength(2));
    expect(seen!['seller_profile_id'], 's1');
    expect(seen!['status'], 'approved');
  });

  test('getMyReview returns null when not authenticated', () async {
    db.rpcResult = null;
    expect(await repo.getMyReview('s1'), isNull);
  });

  test(
    'createReview sends only allowed columns with resolved profile',
    () async {
      await repo.createReview(
        sellerProfileId: 's1',
        rating: 4,
        title: '  Great  ',
        comment: '   ',
      );

      final values = db.inserted.single;
      expect(values['profile_id'], 'profile-1');
      expect(values['seller_profile_id'], 's1');
      expect(values['rating'], 4);
      expect(values['title'], 'Great'); // trimmed
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
      repo.createReview(sellerProfileId: 's1', rating: 5),
      throwsA(isA<Failure>()),
    );
  });

  test('createReview maps a duplicate (23505) to a clear failure', () async {
    db.insertError = const ex.DatabaseException('dup', code: '23505');
    await expectLater(
      repo.createReview(sellerProfileId: 's1', rating: 5),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          'You have already reviewed this seller.',
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
    expect(values.containsKey('verified_purchase'), isFalse);
  });

  test('deleteReview deletes by id', () async {
    await repo.deleteReview('r1');
    expect(db.deleted.single['id'], 'r1');
  });
}
