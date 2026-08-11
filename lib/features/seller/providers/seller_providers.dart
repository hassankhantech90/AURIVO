import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/failure.dart';
import '../../profile/domain/entities/seller_profile.dart';
import '../data/repositories/supabase_seller_repository.dart';
import '../data/repositories/supabase_seller_review_repository.dart';
import '../domain/entities/seller_storefront.dart';
import '../domain/repositories/seller_repository.dart';
import '../domain/repositories/seller_review_repository.dart';

/// Repository bindings (lazy services — stay test-safe without an initialized
/// Supabase client).
final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  const service = SupabaseService();
  return SupabaseSellerRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

final sellerReviewRepositoryProvider = Provider<SellerReviewRepository>((ref) {
  const service = SupabaseService();
  return SupabaseSellerReviewRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

/// Verified seller for a product's `seller_id`, or null if the seller is not
/// publicly visible. Used by product detail to render a tappable store link.
final sellerByIdProvider = FutureProvider.family<SellerProfile?, String>((
  ref,
  sellerId,
) {
  return ref.watch(sellerRepositoryProvider).getSellerById(sellerId);
});

enum SellerViewStatus { initial, loading, success, failure }

/// Generic state container for a seller-module resource, mirroring the orders /
/// reviews module style.
class SellerDataState<T> {
  const SellerDataState({
    this.status = SellerViewStatus.initial,
    this.data,
    this.message,
  });

  final SellerViewStatus status;
  final T? data;
  final String? message;

  bool get isLoading => status == SellerViewStatus.loading;

  SellerDataState<T> copyWith({
    SellerViewStatus? status,
    T? data,
    String? message,
    bool clearMessage = false,
  }) {
    return SellerDataState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// Shared run helper that maps actions into loading/success/failure states.
class _Runner<T> {
  _Runner(this._read, this._write);

  final SellerDataState<T> Function() _read;
  final void Function(SellerDataState<T>) _write;

  Future<void> run(Future<T> Function() action) async {
    _write(
      _read().copyWith(status: SellerViewStatus.loading, clearMessage: true),
    );
    try {
      final data = await action();
      _write(SellerDataState<T>(status: SellerViewStatus.success, data: data));
    } catch (error) {
      _write(
        _read().copyWith(
          status: SellerViewStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }
}

// Verified seller directory ---------------------------------------------------

final verifiedSellersProvider =
    StateNotifierProvider<
      VerifiedSellersNotifier,
      SellerDataState<List<SellerProfile>>
    >((ref) {
      return VerifiedSellersNotifier(ref.watch(sellerRepositoryProvider));
    });

class VerifiedSellersNotifier
    extends StateNotifier<SellerDataState<List<SellerProfile>>> {
  VerifiedSellersNotifier(this._repository)
    : super(const SellerDataState<List<SellerProfile>>()) {
    _runner = _Runner<List<SellerProfile>>(() => state, (v) => state = v);
  }

  final SellerRepository _repository;
  late final _Runner<List<SellerProfile>> _runner;

  Future<void> load() => _runner.run(() => _repository.getVerifiedSellers());
}

// Seller storefront (by slug) -------------------------------------------------

final sellerStorefrontProvider =
    StateNotifierProvider.family<
      SellerStorefrontNotifier,
      SellerDataState<SellerStorefront>,
      String
    >((ref, slug) {
      return SellerStorefrontNotifier(
        seller: ref.watch(sellerRepositoryProvider),
        reviews: ref.watch(sellerReviewRepositoryProvider),
        slug: slug,
      );
    });

class SellerStorefrontNotifier
    extends StateNotifier<SellerDataState<SellerStorefront>> {
  SellerStorefrontNotifier({
    required SellerRepository seller,
    required SellerReviewRepository reviews,
    required String slug,
  }) : _seller = seller,
       _reviews = reviews,
       _slug = slug,
       super(const SellerDataState<SellerStorefront>()) {
    _runner = _Runner<SellerStorefront>(() => state, (v) => state = v);
  }

  final SellerRepository _seller;
  final SellerReviewRepository _reviews;
  final String _slug;
  late final _Runner<SellerStorefront> _runner;

  Future<void> load() {
    return _runner.run(() async {
      final seller = await _seller.getSellerBySlug(_slug);
      if (seller == null) {
        throw const Failure(message: 'Store not found.');
      }
      final products = await _seller.getSellerProducts(seller.id);
      final approved = await _reviews.getApprovedReviews(seller.id);
      final mine = await _reviews.getMyReview(seller.id);
      return SellerStorefront(
        seller: seller,
        products: products,
        approvedReviews: approved,
        myReview: mine,
      );
    });
  }

  /// Creates or updates the current user's seller review, then refreshes the
  /// storefront. Returns null on success or a user-facing error message.
  Future<String?> submitReview({
    String? reviewId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    final seller = state.data?.seller;
    if (seller == null) return 'Store not loaded.';
    try {
      if (reviewId != null) {
        await _reviews.updateReview(
          reviewId: reviewId,
          rating: rating,
          title: title,
          comment: comment,
        );
      } else {
        await _reviews.createReview(
          sellerProfileId: seller.id,
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

  /// Deletes the current user's seller review, then refreshes the storefront.
  Future<String?> removeReview(String reviewId) async {
    try {
      await _reviews.deleteReview(reviewId);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
