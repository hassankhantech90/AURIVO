import '../../../../core/utils/db_parsing.dart';

/// Product gallery image (`public.product_images`). [storagePath] is a Supabase
/// Storage object path, not a public URL.
class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.storagePath,
    this.imageType = 'gallery',
    this.altText,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  final String id;
  final String productId;
  final String storagePath;
  final String imageType;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;

  factory ProductImage.fromMap(Map<String, dynamic> map) {
    return ProductImage(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      storagePath: map['storage_path'] as String,
      imageType: map['image_type'] as String? ?? 'gallery',
      altText: map['alt_text'] as String?,
      sortOrder: parseInt(map['sort_order']),
      isPrimary: map['is_primary'] as bool? ?? false,
    );
  }
}
