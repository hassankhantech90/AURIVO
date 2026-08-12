import '../../../../core/utils/db_parsing.dart';

/// A seller-managed product image (`public.product_images`).
///
/// [storagePath] is the in-bucket object path (`{product_id}/...`) that the
/// storage policies key on; [publicUrl] is derived by the repository from the
/// public `product-images` bucket.
class SellerImage {
  const SellerImage({
    required this.id,
    required this.productId,
    required this.storagePath,
    this.publicUrl = '',
    this.imageType = 'gallery',
    this.altText,
    this.sortOrder = 0,
    this.isPrimary = false,
    this.createdAt,
  });

  final String id;
  final String productId;
  final String storagePath;
  final String publicUrl;
  final String imageType;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;
  final DateTime? createdAt;

  SellerImage withPublicUrl(String url) => SellerImage(
    id: id,
    productId: productId,
    storagePath: storagePath,
    publicUrl: url,
    imageType: imageType,
    altText: altText,
    sortOrder: sortOrder,
    isPrimary: isPrimary,
    createdAt: createdAt,
  );

  factory SellerImage.fromMap(Map<String, dynamic> map) {
    return SellerImage(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      storagePath: map['storage_path'] as String,
      imageType: map['image_type'] as String? ?? 'gallery',
      altText: map['alt_text'] as String?,
      sortOrder: parseInt(map['sort_order']),
      isPrimary: map['is_primary'] as bool? ?? false,
      createdAt: parseTimestamp(map['created_at']),
    );
  }
}
