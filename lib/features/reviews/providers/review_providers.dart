import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_review_repository.dart';
import '../domain/entities/product_review.dart';
import '../domain/repositories/review_repository.dart';

/// Repository binding for the reviews module (lazy services — stays test-safe
/// without an initialized Supabase client).
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  const service = SupabaseService();
  return SupabaseReviewRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

/// Aggregate read shape for a product's reviews section: the approved reviews,
/// the current user's own review (if any), and the delivered order item they
/// may review against. The average is computed on the client from the loaded
/// approved reviews.
class ProductReviewsView {
  const ProductReviewsView({
    this.approved = const [],
    this.myReview,
    this.eligibleOrderItemId,
  });

  final List<ProductReview> approved;
  final ProductReview? myReview;

  /// Only buyers who received this product may review it (Requirements Doc
  /// §3); null when the user has no delivered order item for it.
  final String? eligibleOrderItemId;

  int get reviewCount => approved.length;

  bool get hasApproved => approved.isNotEmpty;

  bool get hasMyReview => myReview != null;

  bool get canWrite => hasMyReview || eligibleOrderItemId != null;

  /// Average of the loaded approved reviews (0 when there are none).
  double get averageRating {
    if (approved.isEmpty) return 0;
    final sum = approved.fold<int>(0, (total, r) => total + r.rating);
    return sum / approved.length;
  }
}

enum ReviewViewStatus { initial, loading, success, failure }

/// Generic state container for a reviews-module resource, mirroring the orders
/// module's [OrderDataState] style.
class ReviewDataState<T> {
  const ReviewDataState({
    this.status = ReviewViewStatus.initial,
    this.data,
    this.message,
  });

  final ReviewViewStatus status;
  final T? data;
  final String? message;

  bool get isLoading => status == ReviewViewStatus.loading;

  ReviewDataState<T> copyWith({
    ReviewViewStatus? status,
    T? data,
    String? message,
    bool clearMessage = false,
  }) {
    return ReviewDataState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// Shared run helper that maps actions into loading/success/failure states.
class _Runner<T> {
  _Runner(this._read, this._write);

  final ReviewDataState<T> Function() _read;
  final void Function(ReviewDataState<T>) _write;

  Future<void> run(Future<T> Function() action) async {
    _write(
      _read().copyWith(status: ReviewViewStatus.loading, clearMessage: true),
    );
    try {
      final data = await action();
      _write(ReviewDataState<T>(status: ReviewViewStatus.success, data: data));
    } catch (error) {
      _write(
        _read().copyWith(
          status: ReviewViewStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }
}

/// Product reviews section state, keyed by product id.
final productReviewsProvider =
    StateNotifierProvider.family<
      ProductReviewsNotifier,
      ReviewDataState<ProductReviewsView>,
      String
    >((ref, productId) {
      return ProductReviewsNotifier(
        ref.watch(reviewRepositoryProvider),
        productId,
      );
    });

class ProductReviewsNotifier
    extends StateNotifier<ReviewDataState<ProductReviewsView>> {
  ProductReviewsNotifier(this._repository, this._productId)
    : super(const ReviewDataState<ProductReviewsView>()) {
    _runner = _Runner<ProductReviewsView>(
      () => state,
      (value) => state = value,
    );
  }

  final ReviewRepository _repository;
  final String _productId;
  late final _Runner<ProductReviewsView> _runner;

  Future<void> load() {
    return _runner.run(() async {
      final approved = await _repository.getApprovedReviews(_productId);
      final myReview = await _repository.getMyReviewForProduct(_productId);
      final eligibleOrderItemId = myReview == null
          ? await _repository.reviewableOrderItemId(_productId)
          : null;
      return ProductReviewsView(
        approved: approved,
        myReview: myReview,
        eligibleOrderItemId: eligibleOrderItemId,
      );
    });
  }

  /// Creates or updates the current user's review, then refreshes the section.
  /// Returns null on success, or a user-facing error message on failure (the
  /// loaded list is left intact so it stays visible under the form sheet).
  Future<String?> submit({
    String? reviewId,
    String? orderItemId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    try {
      if (reviewId != null) {
        await _repository.updateReview(
          reviewId: reviewId,
          rating: rating,
          title: title,
          comment: comment,
        );
      } else {
        await _repository.createReview(
          productId: _productId,
          orderItemId: orderItemId,
          rating: rating,
          title: title,
          comment: comment,
        );
      }
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  /// Deletes the current user's review, then refreshes the section.
  Future<String?> remove(String reviewId) async {
    try {
      await _repository.deleteReview(reviewId);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}

/// The current user's own review for a product — used by the order-detail
/// screen to choose between "Write a review" and "Edit review". Null when the
/// user has none or is not signed in.
final myProductReviewProvider = FutureProvider.family<ProductReview?, String>((
  ref,
  productId,
) {
  return ref.watch(reviewRepositoryProvider).getMyReviewForProduct(productId);
});
