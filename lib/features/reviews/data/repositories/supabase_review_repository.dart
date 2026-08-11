import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../domain/entities/product_review.dart';
import '../../domain/entities/review_status.dart';
import '../../domain/repositories/review_repository.dart';
import '../review_failure_mapper.dart';

/// Supabase-backed [ReviewRepository].
///
/// All writes are plain, RLS-governed table operations — there is no review
/// RPC. The `enforce_product_review_integrity` trigger owns `status`,
/// `verified_purchase`, and `helpful_count`, so this class deliberately never
/// sends those columns; it only forwards `product_id`, the resolved
/// `profile_id`, optional `order_item_id`, `rating`, `title`, and `comment`.
class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _table = 'product_reviews';

  @override
  Future<List<ProductReview>> getApprovedReviews(
    String productId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _database.list(
        table: _table,
        // RLS already restricts anonymous/other-user reads to approved,
        // non-deleted rows; the explicit status filter also uses the
        // (product_id, status) index.
        filters: {'product_id': productId, 'status': ReviewStatus.approved},
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
        offset: offset,
      );
      return rows.map(ProductReview.fromMap).toList();
    } catch (error) {
      throw ReviewFailureMapper.map(error);
    }
  }

  @override
  Future<ProductReview?> getMyReviewForProduct(String productId) async {
    try {
      final profileId = await _currentProfileId();
      if (profileId == null) return null;
      final rows = await _database.list(
        table: _table,
        filters: {'profile_id': profileId, 'product_id': productId},
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ProductReview.fromMap(rows.first);
    } catch (error) {
      throw ReviewFailureMapper.map(error);
    }
  }

  @override
  Future<ProductReview> createReview({
    required String productId,
    String? orderItemId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    try {
      final profileId = await _requireProfileId();
      final values = <String, dynamic>{
        'profile_id': profileId,
        'product_id': productId,
        'rating': rating,
        'order_item_id': ?orderItemId,
        'title': ?_clean(title),
        'comment': ?_clean(comment),
      };
      // Never send status / verified_purchase / helpful_count — the trigger
      // owns those and would override client values anyway.
      final row = await _database.insert(table: _table, values: values);
      return ProductReview.fromMap(row);
    } catch (error) {
      throw ReviewFailureMapper.map(error);
    }
  }

  @override
  Future<ProductReview> updateReview({
    required String reviewId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    try {
      // Send title/comment explicitly (null clears them). order_item_id is left
      // untouched so the trigger keeps the existing verified_purchase basis.
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
      return ProductReview.fromMap(row);
    } catch (error) {
      throw ReviewFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    try {
      // RLS scopes the delete to the owner's own row.
      await _database.delete(
        table: _table,
        matchColumn: 'id',
        matchValue: reviewId,
      );
    } catch (error) {
      throw ReviewFailureMapper.map(error);
    }
  }

  /// Current profile id, or null when there is no authenticated session.
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
