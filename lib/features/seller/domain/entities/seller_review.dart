import '../../../../core/utils/db_parsing.dart';
import '../../../reviews/domain/entities/review_status.dart';

/// A seller review (`public.seller_reviews`).
///
/// Mirrors the product-review model: `status`, `verified_purchase` are
/// maintained server-side by the `enforce_seller_review_integrity` trigger —
/// the client never sends them. Only `approved` reviews are publicly readable;
/// the author can additionally read their own review in any status.
class SellerReview {
  const SellerReview({
    required this.id,
    required this.profileId,
    required this.sellerProfileId,
    required this.rating,
    this.title,
    this.comment,
    this.status = ReviewStatus.pending,
    this.verifiedPurchase = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String profileId;
  final String sellerProfileId;
  final int rating;
  final String? title;
  final String? comment;
  final String status;
  final bool verifiedPurchase;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => ReviewStatus.isPending(status);
  bool get isApproved => ReviewStatus.isApproved(status);

  factory SellerReview.fromMap(Map<String, dynamic> map) {
    return SellerReview(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      sellerProfileId: map['seller_profile_id'] as String,
      rating: parseInt(map['rating']),
      title: map['title'] as String?,
      comment: map['comment'] as String?,
      status: map['status'] as String? ?? ReviewStatus.pending,
      verifiedPurchase: map['verified_purchase'] as bool? ?? false,
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
