import '../entities/seller_review.dart';

/// Contract for reading and writing seller reviews.
///
/// Mirrors the product-review contract: writes are direct, RLS-governed table
/// operations (there is no seller-review RPC). The
/// `enforce_seller_review_integrity` trigger forces `status = 'pending'` and
/// computes `verified_purchase` server-side, so this repository must **never**
/// send `status` or `verified_purchase`. Ownership and moderation are enforced
/// entirely by live RLS + the trigger.
///
/// Implementations must never surface raw Supabase exceptions; all failures are
/// mapped to the shared `Failure` type.
abstract class SellerReviewRepository {
  /// Approved, non-deleted reviews for [sellerProfileId], newest first.
  Future<List<SellerReview>> getApprovedReviews(
    String sellerProfileId, {
    int limit,
    int offset,
  });

  /// The current user's own review for [sellerProfileId] (any status), or null
  /// if they have none or are not signed in.
  Future<SellerReview?> getMyReview(String sellerProfileId);

  /// Whether the current user has a delivered order from [sellerProfileId]
  /// (required to write a store review). False when not signed in.
  Future<bool> canReviewSeller(String sellerProfileId);

  /// Creates a review for [sellerProfileId]. [rating] must be 1–5. The trigger
  /// determines `verified_purchase` from the buyer's delivered/completed orders
  /// with this seller — no order reference is passed by the client.
  Future<SellerReview> createReview({
    required String sellerProfileId,
    required int rating,
    String? title,
    String? comment,
  });

  /// Updates the current user's review [reviewId]. Editing re-enters moderation
  /// (`status` returns to `pending`) server-side.
  Future<SellerReview> updateReview({
    required String reviewId,
    required int rating,
    String? title,
    String? comment,
  });

  /// Deletes the current user's review [reviewId] (RLS scopes to the owner).
  Future<void> deleteReview(String reviewId);
}
