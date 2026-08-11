import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../../reviews/domain/entities/review_status.dart';
import '../../domain/entities/seller_review.dart';
import '../../domain/repositories/seller_review_repository.dart';
import '../seller_failure_mapper.dart';

/// Supabase-backed [SellerReviewRepository].
///
/// All writes are plain, RLS-governed table operations — there is no
/// seller-review RPC. The `enforce_seller_review_integrity` trigger owns
/// `status` and `verified_purchase`, so this class deliberately never sends
/// those columns; it only forwards the resolved `profile_id`,
/// `seller_profile_id`, `rating`, `title`, and `comment`.
class SupabaseSellerReviewRepository implements SellerReviewRepository {
  SupabaseSellerReviewRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _table = 'seller_reviews';

  @override
  Future<List<SellerReview>> getApprovedReviews(
    String sellerProfileId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _database.list(
        table: _table,
        filters: {
          'seller_profile_id': sellerProfileId,
          'status': ReviewStatus.approved,
        },
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
        offset: offset,
      );
      return rows.map(SellerReview.fromMap).toList();
    } catch (error) {
      throw SellerFailureMapper.map(error);
    }
  }

  @override
  Future<SellerReview?> getMyReview(String sellerProfileId) async {
    try {
      final profileId = await _currentProfileId();
      if (profileId == null) return null;
      final rows = await _database.list(
        table: _table,
        filters: {
          'profile_id': profileId,
          'seller_profile_id': sellerProfileId,
        },
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return SellerReview.fromMap(rows.first);
    } catch (error) {
      throw SellerFailureMapper.map(error);
    }
  }

  @override
  Future<SellerReview> createReview({
    required String sellerProfileId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    try {
      final profileId = await _requireProfileId();
      final values = <String, dynamic>{
        'profile_id': profileId,
        'seller_profile_id': sellerProfileId,
        'rating': rating,
        'title': ?_clean(title),
        'comment': ?_clean(comment),
      };
      // Never send status / verified_purchase — the trigger owns those.
      final row = await _database.insert(table: _table, values: values);
      return SellerReview.fromMap(row);
    } catch (error) {
      throw SellerFailureMapper.map(error);
    }
  }

  @override
  Future<SellerReview> updateReview({
    required String reviewId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    try {
      final row = await _database.update(
        table: _table,
        values: {
          'rating': rating,
          'title': _clean(title),
          'comment': _clean(comment),
        },
        matchColumn: 'id',
        matchValue: reviewId,
      );
      return SellerReview.fromMap(row);
    } catch (error) {
      throw SellerFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    try {
      await _database.delete(
        table: _table,
        matchColumn: 'id',
        matchValue: reviewId,
      );
    } catch (error) {
      throw SellerFailureMapper.map(error);
    }
  }

  Future<String?> _currentProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) return result;
    return null;
  }

  Future<String> _requireProfileId() async {
    final profileId = await _currentProfileId();
    if (profileId == null) {
      throw const Failure(message: 'Please sign in to write a review.');
    }
    return profileId;
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
