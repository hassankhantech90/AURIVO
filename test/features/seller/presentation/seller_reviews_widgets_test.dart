import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/seller/domain/entities/seller_review.dart';
import 'package:aurivo/features/seller/domain/entities/seller_storefront.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_repository.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_review_repository.dart';
import 'package:aurivo/features/seller/presentation/widgets/seller_review_tile.dart';
import 'package:aurivo/features/seller/presentation/widgets/seller_reviews_section.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

SellerProfile _seller() => SellerProfile(
  id: 's1',
  profileId: 'p1',
  storeName: 'Gold House',
  slug: 'gold-house',
  verificationStatus: 'verified',
);

SellerReview _review({
  String id = 'r1',
  int rating = 4,
  String status = 'approved',
  bool verified = false,
  String? title,
}) => SellerReview(
  id: id,
  profileId: 'p1',
  sellerProfileId: 's1',
  rating: rating,
  status: status,
  verifiedPurchase: verified,
  title: title,
);

class _FakeSellerRepository implements SellerRepository {
  @override
  Future<List<SellerProfile>> getVerifiedSellers({
    int limit = 20,
    int offset = 0,
  }) async => [_seller()];

  @override
  Future<SellerProfile?> getSellerBySlug(String slug) async => _seller();

  @override
  Future<SellerProfile?> getSellerById(String id) async => _seller();

  @override
  Future<List<Product>> getSellerProducts(
    String sellerId, {
    int limit = 20,
    int offset = 0,
  }) async => const [];
}

class _FakeSellerReviewRepository implements SellerReviewRepository {
  @override
  Future<List<SellerReview>> getApprovedReviews(
    String sellerProfileId, {
    int limit = 50,
    int offset = 0,
  }) async => const [];

  @override
  Future<SellerReview?> getMyReview(String sellerProfileId) async => null;

  @override
  Future<bool> canReviewSeller(String sellerProfileId) async => false;

  @override
  Future<SellerReview> createReview({
    required String sellerProfileId,
    required int rating,
    String? title,
    String? comment,
  }) async => throw UnimplementedError();

  @override
  Future<SellerReview> updateReview({
    required String reviewId,
    required int rating,
    String? title,
    String? comment,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteReview(String reviewId) async {}
}

Widget _wrapSection(SellerStorefront storefront) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            child: SellerReviewsSection(
              slug: 'gold-house',
              storefront: storefront,
            ),
          ),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sellerRepositoryProvider.overrideWithValue(_FakeSellerRepository()),
      sellerReviewRepositoryProvider.overrideWithValue(
        _FakeSellerReviewRepository(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('SellerReviewTile shows verified badge and anonymous buyer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SellerReviewTile(
            review: _review(verified: true, title: 'Trustworthy'),
          ),
        ),
      ),
    );

    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Verified Buyer'), findsOneWidget);
    expect(find.text('Trustworthy'), findsOneWidget);
  });

  testWidgets('SellerReviewTile shows pending status for the author', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SellerReviewTile(
            review: _review(status: 'pending'),
            isMine: true,
          ),
        ),
      ),
    );

    expect(find.text('Pending approval'), findsOneWidget);
    expect(find.text('(You)'), findsOneWidget);
  });

  testWidgets('section shows empty state and guest sign-in prompt', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapSection(SellerStorefront(seller: _seller())));
    await tester.pumpAndSettle();

    expect(find.textContaining('No reviews yet'), findsOneWidget);
    expect(find.text('Sign in to write a review'), findsOneWidget);
  });

  testWidgets('section renders approved reviews', (tester) async {
    await tester.pumpWidget(
      _wrapSection(
        SellerStorefront(
          seller: _seller(),
          approvedReviews: [
            _review(id: 'a', title: 'First'),
            _review(id: 'b', title: 'Second'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SellerReviewTile), findsNWidgets(2));
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });
}
