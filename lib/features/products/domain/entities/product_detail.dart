import 'product.dart';
import 'product_image.dart';
import 'product_variant.dart';

/// Aggregate read shape for the product detail screen: the product plus its
/// gallery images and sellable variants.
class ProductDetail {
  const ProductDetail({
    required this.product,
    this.images = const [],
    this.variants = const [],
  });

  final Product product;
  final List<ProductImage> images;
  final List<ProductVariant> variants;

  ProductImage? get primaryImage {
    for (final image in images) {
      if (image.isPrimary) return image;
    }
    return images.isNotEmpty ? images.first : null;
  }
}
