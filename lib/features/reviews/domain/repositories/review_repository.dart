import '../entities/product_review.dart';

/// Contract for reading and writing product reviews.
///
/// Reviews are written by direct, RLS-governed table writes — there is no
/// review RPC. The database `enforce_product_review_integrity` trigger forces
/// `status = 'pending'`, resets `helpful_count`, and computes
/// `verified_purchase` server-side, so this repository must **never** send
/// `status`, `verified_purchase`, or `helpful_count`. Ownership and moderation
/// are enforced entirely by live RLS + the trigger.
///
/// Implementations must never surface raw Supabase exceptions; all failures are
/// mapped to the shared `Failure` type.
abstract class ReviewRepository {
  /// Approved, non-deleted reviews for [productId], newest first.
  Future<List<ProductReview>> getApprovedReviews(
    String productId, {
    int limit,
    int offset,
  });

  /// The current user's own review for [productId] (any status), or null if
  /// they have none or are not signed in.
  Future<ProductReview?> getMyReviewForProduct(String productId);

  /// Creates a review for [productId]. Pass [orderItemId] when the review is
  /// written from a purchased order item so the trigger can set
  /// `verified_purchase`. [rating] must be 1–5.
  Future<ProductReview> createReview({
    required String productId,
    String? orderItemId,
    required int rating,
    String? title,
    String? comment,
  });

  /// Updates the current user's review [reviewId]. Editing re-enters moderation
  /// (`status` returns to `pending`) server-side.
  Future<ProductReview> updateReview({
    required String reviewId,
    required int rating,
    String? title,
    String? comment,
  });

  /// Deletes the current user's review [reviewId] (RLS scopes to the owner).
  Future<void> deleteReview(String reviewId);
}
