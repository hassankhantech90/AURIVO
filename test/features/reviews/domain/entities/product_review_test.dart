import 'package:aurivo/features/reviews/domain/entities/product_review.dart';
import 'package:aurivo/features/reviews/domain/entities/review_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductReview.fromMap', () {
    test('parses a full row', () {
      final review = ProductReview.fromMap({
        'id': 'r1',
        'profile_id': 'p1',
        'product_id': 'prod-1',
        'order_item_id': 'oi-1',
        'rating': 4,
        'title': 'Lovely',
        'comment': 'Great craftsmanship',
        'images': ['a.jpg', 'b.jpg'],
        'status': 'approved',
        'verified_purchase': true,
        'helpful_count': 3,
        'created_at': '2026-02-01T10:00:00Z',
        'updated_at': '2026-02-02T10:00:00Z',
      });

      expect(review.id, 'r1');
      expect(review.orderItemId, 'oi-1');
      expect(review.rating, 4);
      expect(review.title, 'Lovely');
      expect(review.images, ['a.jpg', 'b.jpg']);
      expect(review.verifiedPurchase, isTrue);
      expect(review.helpfulCount, 3);
      expect(review.isApproved, isTrue);
      expect(review.isPending, isFalse);
      expect(review.createdAt, isNotNull);
    });

    test('applies safe defaults for a minimal row', () {
      final review = ProductReview.fromMap({
        'id': 'r2',
        'profile_id': 'p1',
        'product_id': 'prod-1',
        'rating': 5,
      });

      expect(review.orderItemId, isNull);
      expect(review.title, isNull);
      expect(review.comment, isNull);
      expect(review.images, isEmpty);
      expect(review.status, ReviewStatus.pending);
      expect(review.verifiedPurchase, isFalse);
      expect(review.helpfulCount, 0);
      expect(review.isPending, isTrue);
    });

    test('tolerates a non-list images value', () {
      final review = ProductReview.fromMap({
        'id': 'r3',
        'profile_id': 'p1',
        'product_id': 'prod-1',
        'rating': 3,
        'images': null,
      });
      expect(review.images, isEmpty);
    });
  });

  group('ReviewStatus', () {
    test('labels known statuses', () {
      expect(ReviewStatus.label(ReviewStatus.pending), 'Pending approval');
      expect(ReviewStatus.label(ReviewStatus.approved), 'Published');
      expect(ReviewStatus.isApproved('approved'), isTrue);
      expect(ReviewStatus.isPending('pending'), isTrue);
    });
  });
}
