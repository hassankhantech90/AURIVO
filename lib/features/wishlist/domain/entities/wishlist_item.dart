import '../../../../core/utils/db_parsing.dart';

/// A product saved to the current user's wishlist (`public.wishlist`).
class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.profileId,
    required this.productId,
    this.createdAt,
  });

  final String id;
  final String profileId;
  final String productId;
  final DateTime? createdAt;

  factory WishlistItem.fromMap(Map<String, dynamic> map) {
    return WishlistItem(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      productId: map['product_id'] as String,
      createdAt: parseTimestamp(map['created_at']),
    );
  }
}
