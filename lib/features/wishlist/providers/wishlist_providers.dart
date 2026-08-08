import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_wishlist_repository.dart';
import '../domain/repositories/wishlist_repository.dart';

/// Repository binding for the wishlist (lazy service — stays test-safe without
/// an initialized Supabase client).
final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return SupabaseWishlistRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

enum WishlistStatus { initial, loading, success, failure }

/// Holds the set of wishlisted product ids so any product surface can render a
/// toggle without re-querying per item.
class WishlistState {
  const WishlistState({
    this.status = WishlistStatus.initial,
    this.productIds = const {},
    this.message,
  });

  final WishlistStatus status;
  final Set<String> productIds;
  final String? message;

  bool get isLoading => status == WishlistStatus.loading;
  bool contains(String productId) => productIds.contains(productId);

  WishlistState copyWith({
    WishlistStatus? status,
    Set<String>? productIds,
    String? message,
    bool clearMessage = false,
  }) {
    return WishlistState(
      status: status ?? this.status,
      productIds: productIds ?? this.productIds,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final wishlistProvider = StateNotifierProvider<WishlistNotifier, WishlistState>(
  (ref) {
    return WishlistNotifier(ref.watch(wishlistRepositoryProvider));
  },
);

class WishlistNotifier extends StateNotifier<WishlistState> {
  WishlistNotifier(this._repository) : super(const WishlistState());

  final WishlistRepository _repository;

  /// Loads the current user's wishlisted product ids.
  Future<void> load() async {
    state = state.copyWith(status: WishlistStatus.loading, clearMessage: true);
    try {
      final ids = await _repository.getWishlistedProductIds();
      state = WishlistState(status: WishlistStatus.success, productIds: ids);
    } catch (error) {
      state = state.copyWith(
        status: WishlistStatus.failure,
        message: error.toString(),
      );
    }
  }

  Future<void> add(String productId) async {
    await _mutate(() async {
      await _repository.add(productId);
      return {...state.productIds, productId};
    });
  }

  Future<void> remove(String productId) async {
    await _mutate(() async {
      await _repository.remove(productId);
      return {...state.productIds}..remove(productId);
    });
  }

  /// Adds the product if absent, otherwise removes it.
  Future<void> toggle(String productId) {
    return state.contains(productId) ? remove(productId) : add(productId);
  }

  Future<void> _mutate(Future<Set<String>> Function() action) async {
    state = state.copyWith(status: WishlistStatus.loading, clearMessage: true);
    try {
      final ids = await action();
      state = WishlistState(status: WishlistStatus.success, productIds: ids);
    } catch (error) {
      state = state.copyWith(
        status: WishlistStatus.failure,
        message: error.toString(),
      );
    }
  }
}
