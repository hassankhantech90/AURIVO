import 'dart:typed_data';

import '../entities/seller_image.dart';

/// Contract for seller-side product image management.
///
/// Images live in the public `product-images` bucket under a
/// `{product_id}/...` path; both the storage object and the `product_images`
/// row are restricted to the seller who owns the product (storage policies +
/// `product_images_seller_all_own`). Ownership is enforced by the database and
/// storage — never supplied by the UI.
abstract class SellerImageRepository {
  /// Images for [productId] (primary first, then sort order), each with a
  /// resolved public URL. Excludes soft-deleted rows.
  Future<List<SellerImage>> getImages(String productId);

  /// Uploads [bytes] to `product-images/{productId}/...` and inserts the
  /// matching `product_images` row. The first image of a product becomes
  /// primary automatically.
  Future<SellerImage> uploadImage({
    required String productId,
    required Uint8List bytes,
    required String fileExtension,
    String? contentType,
    String? altText,
  });

  /// Makes [imageId] the primary image for [productId].
  Future<void> setPrimary(String productId, String imageId);

  /// Persists a new display order (updates each image's `sort_order`).
  Future<void> reorder(String productId, List<String> orderedImageIds);

  /// Deletes an image: removes the storage object and the `product_images`
  /// row. If it was primary, promotes the next remaining image.
  Future<void> deleteImage(SellerImage image);
}
