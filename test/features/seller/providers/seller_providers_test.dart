import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/seller/domain/entities/seller_review.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_repository.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_review_repository.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerProfile _seller({String slug = 'gold-house'}) => SellerProfile(
  id: 's1',
  profileId: 'p1',
  storeName: 'Gold House',
  slug: slug,
  verificationStatus: 'verified',
);

SellerReview _review({String id = 'r1', int rating = 4}) => SellerReview(
  id: id,
  profileId: 'p1',
  sellerProfileId: 's1',
  rating: rating,
  status: 'approved',
);

class _FakeSellerRepository implements SellerRepository {
  _FakeSellerRepository({this.seller, this.error});
  final SellerProfile? seller;
  final Object? error;

  @override
  Future<List<SellerProfile>> getVerifiedSellers({
    int limit = 20,
    int offset = 0,
  }) async {
    if (error != null) throw error!;
    return seller == null ? const [] : [seller!];
  }

  @override
  Future<SellerProfile?> getSellerBySlug(String slug) async {
    if (error != null) throw error!;
    return seller;
  }

  @override
  Future<SellerProfile?> getSellerById(String id) async => seller;

  @override
  Future<List<Product>> getSellerProducts(
    String sellerId, {
    int limit = 20,
    int offset = 0,
  }) async => const [];
}

class _FakeSellerReviewRepository implements SellerReviewRepository {
  _FakeSellerReviewRepository({
    this.approved = const [],
    this.mine,
    this.canReview = false,
  });
  List<SellerReview> approved;
  SellerReview? mine;
  final bool canReview;

  @override
  Future<bool> canReviewSeller(String sellerProfileId) async => canReview;

  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<SellerReview>> getApprovedReviews(
    String sellerProfileId, {
    int limit = 50,
    int offset = 0,
  }) async => approved;

  @override
  Future<SellerReview?> getMyReview(String sellerProfileId) async => mine;

  @override
  Future<SellerReview> createReview({
    required String sellerProfileId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    createCalls++;
    final created = _review(id: 'new', rating: rating);
    mine = created;
    return created;
  }

  @override
  Future<SellerReview> updateReview({
    required String reviewId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    updateCalls++;
    final updated = _review(id: reviewId, rating: rating);
    mine = updated;
    return updated;
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    deleteCalls++;
    mine = null;
  }
}

ProviderContainer _container({
  required SellerRepository seller,
  required SellerReviewRepository reviews,
}) {
  final container = ProviderContainer(
    overrides: [
      sellerRepositoryProvider.overrideWithValue(seller),
      sellerReviewRepositoryProvider.overrideWithValue(reviews),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('verifiedSellersProvider', () {
    test('load exposes verified sellers', () async {
      final container = _container(
        seller: _FakeSellerRepository(seller: _seller()),
        reviews: _FakeSellerReviewRepository(),
      );

      await container.read(verifiedSellersProvider.notifier).load();

      final state = container.read(verifiedSellersProvider);
      expect(state.status, SellerViewStatus.success);
      expect(state.data!.single.slug, 'gold-house');
    });

    test('load failure surfaces the message', () async {
      final container = _container(
        seller: _FakeSellerRepository(error: const Failure(message: 'offline')),
        reviews: _FakeSellerReviewRepository(),
      );

      await container.read(verifiedSellersProvider.notifier).load();

      final state = container.read(verifiedSellersProvider);
      expect(state.status, SellerViewStatus.failure);
      expect(state.message, 'offline');
    });
  });

  group('sellerStorefrontProvider', () {
    test('load builds the storefront with client-computed rating', () async {
      final container = _container(
        seller: _FakeSellerRepository(seller: _seller()),
        reviews: _FakeSellerReviewRepository(
          approved: [_review(rating: 5), _review(rating: 3)],
        ),
      );

      await container
          .read(sellerStorefrontProvider('gold-house').notifier)
          .load();

      final state = container.read(sellerStorefrontProvider('gold-house'));
      expect(state.status, SellerViewStatus.success);
      expect(state.data!.averageRating, 4.0);
      expect(state.data!.reviewCount, 2);
      expect(state.data!.canWrite, isFalse); // no delivered order, no review
    });

    test('a buyer with a delivered order from the store may review', () async {
      final container = _container(
        seller: _FakeSellerRepository(seller: _seller()),
        reviews: _FakeSellerReviewRepository(canReview: true),
      );

      await container
          .read(sellerStorefrontProvider('gold-house').notifier)
          .load();

      final data = container.read(sellerStorefrontProvider('gold-house')).data!;
      expect(data.canReview, isTrue);
      expect(data.canWrite, isTrue);
    });

    test('load fails when the store is not visible', () async {
      final container = _container(
        seller: _FakeSellerRepository(seller: null),
        reviews: _FakeSellerReviewRepository(),
      );

      await container.read(sellerStorefrontProvider('missing').notifier).load();

      final state = container.read(sellerStorefrontProvider('missing'));
      expect(state.status, SellerViewStatus.failure);
      expect(state.message, 'Store not found.');
    });

    test('submitReview creates then reloads', () async {
      final reviews = _FakeSellerReviewRepository();
      final container = _container(
        seller: _FakeSellerRepository(seller: _seller()),
        reviews: reviews,
      );
      final notifier = container.read(
        sellerStorefrontProvider('gold-house').notifier,
      );
      await notifier.load();

      final error = await notifier.submitReview(rating: 5, title: 'Great');

      expect(error, isNull);
      expect(reviews.createCalls, 1);
      expect(
        container
            .read(sellerStorefrontProvider('gold-house'))
            .data!
            .hasMyReview,
        isTrue,
      );
    });

    test('submitReview with reviewId updates instead of creating', () async {
      final reviews = _FakeSellerReviewRepository(mine: _review());
      final container = _container(
        seller: _FakeSellerRepository(seller: _seller()),
        reviews: reviews,
      );
      final notifier = container.read(
        sellerStorefrontProvider('gold-house').notifier,
      );
      await notifier.load();

      final error = await notifier.submitReview(reviewId: 'r1', rating: 2);

      expect(error, isNull);
      expect(reviews.updateCalls, 1);
      expect(reviews.createCalls, 0);
    });

    test('removeReview deletes then reloads', () async {
      final reviews = _FakeSellerReviewRepository(mine: _review());
      final container = _container(
        seller: _FakeSellerRepository(seller: _seller()),
        reviews: reviews,
      );
      final notifier = container.read(
        sellerStorefrontProvider('gold-house').notifier,
      );
      await notifier.load();

      final error = await notifier.removeReview('r1');

      expect(error, isNull);
      expect(reviews.deleteCalls, 1);
      expect(
        container
            .read(sellerStorefrontProvider('gold-house'))
            .data!
            .hasMyReview,
        isFalse,
      );
    });
  });
}
