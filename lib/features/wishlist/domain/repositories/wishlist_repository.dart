import '../entities/wishlist_item.dart';

/// Contract for the authenticated user's product wishlist.
///
/// Wishlist access is authenticated-only under the existing RLS (rows are
/// scoped to `profile_id = current_profile_id()`). Implementations throw the
/// shared `Failure` type rather than raw Supabase exceptions.
abstract class WishlistRepository {
  /// The current user's wishlist entries (most recent first).
  Future<List<WishlistItem>> getWishlist();

  /// The set of product ids currently wishlisted by the user.
  Future<Set<String>> getWishlistedProductIds();

  /// Whether [productId] is in the current user's wishlist.
  Future<bool> isWishlisted(String productId);

  /// Adds [productId] to the wishlist. Idempotent — a product already present
  /// is left unchanged (respecting the `UNIQUE(profile_id, product_id)`
  /// constraint) and the existing/created entry is returned.
  Future<WishlistItem> add(String productId);

  /// Removes [productId] from the wishlist. No-op if it was not present.
  Future<void> remove(String productId);
}
