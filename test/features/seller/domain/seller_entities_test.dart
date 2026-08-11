import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/seller/domain/entities/seller_review.dart';
import 'package:aurivo/features/seller/domain/entities/seller_storefront.dart';
import 'package:flutter_test/flutter_test.dart';

SellerProfile _seller() => SellerProfile.fromMap({
  'id': 's1',
  'profile_id': 'p1',
  'store_name': 'Gold House',
  'slug': 'gold-house',
  'verification_status': 'verified',
});

SellerReview _review({int rating = 4, String status = 'approved'}) =>
    SellerReview(
      id: 'r-$rating',
      profileId: 'p1',
      sellerProfileId: 's1',
      rating: rating,
      status: status,
    );

void main() {
  group('SellerReview.fromMap', () {
    test('parses a full row', () {
      final review = SellerReview.fromMap({
        'id': 'r1',
        'profile_id': 'p1',
        'seller_profile_id': 's1',
        'rating': 5,
        'title': 'Trustworthy',
        'comment': 'Fast shipping',
        'status': 'approved',
        'verified_purchase': true,
        'created_at': '2026-02-01T00:00:00Z',
      });

      expect(review.rating, 5);
      expect(review.title, 'Trustworthy');
      expect(review.verifiedPurchase, isTrue);
      expect(review.isApproved, isTrue);
      expect(review.isPending, isFalse);
    });

    test('applies safe defaults', () {
      final review = SellerReview.fromMap({
        'id': 'r2',
        'profile_id': 'p1',
        'seller_profile_id': 's1',
        'rating': 3,
      });
      expect(review.title, isNull);
      expect(review.status, 'pending');
      expect(review.verifiedPurchase, isFalse);
      expect(review.isPending, isTrue);
    });
  });

  group('SellerStorefront', () {
    test('averageRating and reviewCount come from approved reviews', () {
      final storefront = SellerStorefront(
        seller: _seller(),
        approvedReviews: [_review(rating: 5), _review(rating: 2)],
      );
      expect(storefront.reviewCount, 2);
      expect(storefront.averageRating, 3.5);
      expect(storefront.hasReviews, isTrue);
    });

    test('averageRating is 0 with no reviews', () {
      final storefront = SellerStorefront(seller: _seller());
      expect(storefront.averageRating, 0);
      expect(storefront.hasReviews, isFalse);
      expect(storefront.hasMyReview, isFalse);
    });

    test('hasProducts reflects the product list', () {
      final storefront = SellerStorefront(
        seller: _seller(),
        products: [
          Product.fromMap({
            'id': 'prod-1',
            'seller_id': 's1',
            'title': 'Ring',
            'slug': 'ring',
            'jewellery_type': 'ring',
            'base_price': 1000,
          }),
        ],
      );
      expect(storefront.hasProducts, isTrue);
      expect(storefront.productCount, 1);
    });
  });
}
