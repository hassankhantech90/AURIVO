import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/reviews/domain/entities/product_review.dart';
import 'package:aurivo/features/reviews/domain/repositories/review_repository.dart';
import 'package:aurivo/features/reviews/providers/review_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProductReview _review({
  String id = 'r1',
  String productId = 'prod-1',
  int rating = 4,
  String status = 'approved',
  bool verified = false,
}) => ProductReview(
  id: id,
  profileId: 'p1',
  productId: productId,
  rating: rating,
  status: status,
  verifiedPurchase: verified,
);

class _FakeReviewRepository implements ReviewRepository {
  _FakeReviewRepository({
    this.approved = const [],
    this.mine,
    this.createError,
    this.eligibleItem,
  });

  List<ProductReview> approved;
  ProductReview? mine;
  final Object? createError;
  final String? eligibleItem;

  int createCalls = 0;
  int eligibilityCalls = 0;
  String? lastOrderItemId;

  @override
  Future<String?> reviewableOrderItemId(String productId) async {
    eligibilityCalls++;
    return eligibleItem;
  }
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<ProductReview>> getApprovedReviews(
    String productId, {
    int limit = 50,
    int offset = 0,
  }) async => approved;

  @override
  Future<ProductReview?> getMyReviewForProduct(String productId) async => mine;

  @override
  Future<ProductReview> createReview({
    required String productId,
    String? orderItemId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    createCalls++;
    lastOrderItemId = orderItemId;
    if (createError != null) throw createError!;
    final created = _review(id: 'new', rating: rating, status: 'pending');
    mine = created;
    return created;
  }

  @override
  Future<ProductReview> updateReview({
    required String reviewId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    updateCalls++;
    final updated = _review(id: reviewId, rating: rating, status: 'pending');
    mine = updated;
    return updated;
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    deleteCalls++;
    mine = null;
  }
}

ProviderContainer _container(ReviewRepository repo) {
  final container = ProviderContainer(
    overrides: [reviewRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ProductReviewsView', () {
    test('averageRating is computed from approved reviews', () {
      final view = ProductReviewsView(
        approved: [
          _review(id: 'a', rating: 5),
          _review(id: 'b', rating: 2),
        ],
      );
      expect(view.reviewCount, 2);
      expect(view.averageRating, 3.5);
      expect(view.hasApproved, isTrue);
    });

    test('averageRating is 0 with no approved reviews', () {
      const view = ProductReviewsView();
      expect(view.averageRating, 0);
      expect(view.hasApproved, isFalse);
    });
  });

  group('productReviewsProvider', () {
    test('load exposes approved reviews and my review', () async {
      final repo = _FakeReviewRepository(
        approved: [
          _review(id: 'a'),
          _review(id: 'b'),
        ],
        mine: _review(id: 'a'),
      );
      final container = _container(repo);

      await container.read(productReviewsProvider('prod-1').notifier).load();

      final state = container.read(productReviewsProvider('prod-1'));
      expect(state.status, ReviewViewStatus.success);
      expect(state.data!.reviewCount, 2);
      expect(state.data!.hasMyReview, isTrue);
      expect(state.data!.canWrite, isTrue); // can edit their own review
      expect(repo.eligibilityCalls, 0); // not needed once they have a review
    });

    test('a buyer with a delivered item may write, and it is linked', () async {
      final repo = _FakeReviewRepository(eligibleItem: 'item-9');
      final container = _container(repo);
      final notifier = container.read(productReviewsProvider('prod-1').notifier);

      await notifier.load();
      final view = container.read(productReviewsProvider('prod-1')).data!;
      expect(view.eligibleOrderItemId, 'item-9');
      expect(view.canWrite, isTrue);

      await notifier.submit(orderItemId: view.eligibleOrderItemId, rating: 5);
      expect(repo.lastOrderItemId, 'item-9');
    });

    test('a user who has not received the item cannot write', () async {
      final repo = _FakeReviewRepository();
      final container = _container(repo);

      await container.read(productReviewsProvider('prod-1').notifier).load();

      final view = container.read(productReviewsProvider('prod-1')).data!;
      expect(view.eligibleOrderItemId, isNull);
      expect(view.canWrite, isFalse);
    });

    test('submit create calls createReview then reloads', () async {
      final repo = _FakeReviewRepository();
      final container = _container(repo);
      final notifier = container.read(
        productReviewsProvider('prod-1').notifier,
      );

      final error = await notifier.submit(rating: 5, title: 'Great');

      expect(error, isNull);
      expect(repo.createCalls, 1);
      expect(repo.updateCalls, 0);
      expect(
        container.read(productReviewsProvider('prod-1')).data!.hasMyReview,
        isTrue,
      );
    });

    test('submit with reviewId updates instead of creating', () async {
      final repo = _FakeReviewRepository(mine: _review(id: 'r1'));
      final container = _container(repo);
      final notifier = container.read(
        productReviewsProvider('prod-1').notifier,
      );

      final error = await notifier.submit(reviewId: 'r1', rating: 3);

      expect(error, isNull);
      expect(repo.updateCalls, 1);
      expect(repo.createCalls, 0);
    });

    test('submit returns the failure message on error', () async {
      final repo = _FakeReviewRepository(
        createError: const Failure(
          message: 'You have already reviewed this product.',
        ),
      );
      final container = _container(repo);
      final notifier = container.read(
        productReviewsProvider('prod-1').notifier,
      );

      final error = await notifier.submit(rating: 5);

      expect(error, 'You have already reviewed this product.');
    });

    test('remove deletes then reloads', () async {
      final repo = _FakeReviewRepository(mine: _review(id: 'r1'));
      final container = _container(repo);
      final notifier = container.read(
        productReviewsProvider('prod-1').notifier,
      );

      final error = await notifier.remove('r1');

      expect(error, isNull);
      expect(repo.deleteCalls, 1);
      expect(
        container.read(productReviewsProvider('prod-1')).data!.hasMyReview,
        isFalse,
      );
    });
  });
}
