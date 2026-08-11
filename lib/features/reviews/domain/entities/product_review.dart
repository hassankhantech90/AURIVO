import '../../../../core/utils/db_parsing.dart';
import 'review_status.dart';

/// A product review (`public.product_reviews`).
///
/// [status], [verifiedPurchase] and [helpfulCount] are all maintained
/// server-side by the `enforce_product_review_integrity` trigger — the client
/// never sends them. Only `approved` reviews are publicly readable; a review's
/// author can additionally read their own review in any status.
class ProductReview {
  const ProductReview({
    required this.id,
    required this.profileId,
    required this.productId,
    this.orderItemId,
    required this.rating,
    this.title,
    this.comment,
    this.images = const [],
    this.status = ReviewStatus.pending,
    this.verifiedPurchase = false,
    this.helpfulCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String profileId;
  final String productId;
  final String? orderItemId;
  final int rating;
  final String? title;
  final String? comment;
  final List<String> images;
  final String status;
  final bool verifiedPurchase;
  final int helpfulCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => ReviewStatus.isPending(status);
  bool get isApproved => ReviewStatus.isApproved(status);

  factory ProductReview.fromMap(Map<String, dynamic> map) {
    return ProductReview(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      productId: map['product_id'] as String,
      orderItemId: map['order_item_id'] as String?,
      rating: parseInt(map['rating']),
      title: map['title'] as String?,
      comment: map['comment'] as String?,
      images: _asStringList(map['images']),
      status: map['status'] as String? ?? ReviewStatus.pending,
      verifiedPurchase: map['verified_purchase'] as bool? ?? false,
      helpfulCount: parseInt(map['helpful_count']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  static List<String> _asStringList(Object? value) {
    if (value is List) {
      return value.whereType<Object>().map((e) => e.toString()).toList();
    }
    return const [];
  }
}
