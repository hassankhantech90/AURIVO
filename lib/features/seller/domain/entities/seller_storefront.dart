import '../../../products/domain/entities/product.dart';
import '../../../profile/domain/entities/seller_profile.dart';
import 'seller_review.dart';

/// Aggregate read shape for the seller storefront screen: the (verified) seller
/// profile, their approved products, and their approved reviews. The rating
/// summary is computed on the client from the loaded approved reviews — the DB
/// `seller_profiles.rating_average` aggregate is not maintained and is
/// intentionally not relied upon.
class SellerStorefront {
  const SellerStorefront({
    required this.seller,
    this.products = const [],
    this.approvedReviews = const [],
    this.myReview,
  });

  final SellerProfile seller;
  final List<Product> products;
  final List<SellerReview> approvedReviews;

  /// The current user's own review for this seller (any status), or null.
  final SellerReview? myReview;

  int get productCount => products.length;
  bool get hasProducts => products.isNotEmpty;

  int get reviewCount => approvedReviews.length;
  bool get hasReviews => approvedReviews.isNotEmpty;

  bool get hasMyReview => myReview != null;

  /// Average of the loaded approved reviews (0 when there are none).
  double get averageRating {
    if (approvedReviews.isEmpty) return 0;
    final sum = approvedReviews.fold<int>(0, (total, r) => total + r.rating);
    return sum / approvedReviews.length;
  }
}
