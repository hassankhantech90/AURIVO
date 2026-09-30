import 'package:aurivo/features/reviews/domain/entities/product_review.dart';
import 'package:aurivo/features/reviews/domain/repositories/review_repository.dart';
import 'package:aurivo/features/reviews/presentation/widgets/product_reviews_section.dart';
import 'package:aurivo/features/reviews/presentation/widgets/review_tile.dart';
import 'package:aurivo/features/reviews/presentation/widgets/star_rating_input.dart';
import 'package:aurivo/features/reviews/providers/review_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProductReview _review({
  String id = 'r1',
  int rating = 4,
  String status = 'approved',
  bool verified = false,
  String? title,
  String? comment,
}) => ProductReview(
  id: id,
  profileId: 'p1',
  productId: 'prod-1',
  rating: rating,
  status: status,
  verifiedPurchase: verified,
  title: title,
  comment: comment,
  createdAt: DateTime.utc(2026, 2, 1),
);

class _FakeReviewRepository implements ReviewRepository {
  _FakeReviewRepository({this.approved = const []});
  final List<ProductReview> approved;

  @override
  Future<List<ProductReview>> getApprovedReviews(
    String productId, {
    int limit = 50,
    int offset = 0,
  }) async => approved;

  @override
  Future<ProductReview?> getMyReviewForProduct(String productId) async => null;

  @override
  Future<String?> reviewableOrderItemId(String productId) async => null;

  @override
  Future<ProductReview> createReview({
    required String productId,
    String? orderItemId,
    required int rating,
    String? title,
    String? comment,
  }) async => throw UnimplementedError();

  @override
  Future<ProductReview> updateReview({
    required String reviewId,
    required int rating,
    String? title,
    String? comment,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteReview(String reviewId) async {}
}

Widget _wrapSection(ReviewRepository repo) {
  return ProviderScope(
    overrides: [reviewRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProductReviewsSection(productId: 'prod-1'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('StarRatingInput reports the tapped star', (tester) async {
    int? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StarRatingInput(value: 0, onChanged: (v) => captured = v),
        ),
      ),
    );

    await tester.tap(find.byType(IconButton).at(3));
    expect(captured, 4);
  });

  testWidgets('ReviewTile shows verified badge and anonymous buyer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewTile(
            review: _review(
              verified: true,
              title: 'Beautiful',
              comment: 'Love it',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Verified Buyer'), findsOneWidget);
    expect(find.text('Beautiful'), findsOneWidget);
    expect(find.text('Love it'), findsOneWidget);
  });

  testWidgets('ReviewTile shows pending status for the author', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewTile(review: _review(status: 'pending'), isMine: true),
        ),
      ),
    );

    expect(find.text('Pending approval'), findsOneWidget);
    expect(find.text('(You)'), findsOneWidget);
  });

  testWidgets('section shows empty state and guest sign-in prompt', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapSection(_FakeReviewRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('No reviews yet'), findsOneWidget);
    // Session is unauthenticated in tests (no Supabase config).
    expect(find.text('Sign in to write a review'), findsOneWidget);
  });

  testWidgets('section renders approved reviews', (tester) async {
    await tester.pumpWidget(
      _wrapSection(
        _FakeReviewRepository(
          approved: [
            _review(id: 'a', title: 'First'),
            _review(id: 'b', title: 'Second'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReviewTile), findsNWidgets(2));
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });
}
