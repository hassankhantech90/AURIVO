import '../../../../core/utils/db_parsing.dart';

/// Status value set for `products.status` (mirrors the live CHECK constraint).
/// The seller-facing publish model toggles between [draft] and [approved]
/// (self-publish); `pending`/`rejected` are reserved for a future admin flow.
class ProductStatus {
  const ProductStatus._();

  static const draft = 'draft';
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const archived = 'archived';

  static bool isPublished(String status) => status == approved;

  static String label(String status) {
    switch (status) {
      case draft:
        return 'Draft';
      case pending:
        return 'Pending review';
      case approved:
        return 'Published';
      case rejected:
        return 'Rejected';
      case archived:
        return 'Archived';
      default:
        return status;
    }
  }
}

/// A seller-managed product row (`public.products`) — the seller-side view that
/// includes management fields (`status`, `featured`) omitted from the
/// buyer-facing `Product` entity.
class SellerProduct {
  const SellerProduct({
    required this.id,
    required this.sellerId,
    this.brandId,
    required this.title,
    required this.slug,
    this.description,
    this.shortDescription,
    required this.jewelleryType,
    this.material,
    this.purity,
    this.gender,
    this.occasion,
    this.status = ProductStatus.draft,
    this.featured = false,
    this.currency = 'PKR',
    required this.basePrice,
    this.comparePrice,
    this.minOrderQuantity,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sellerId;
  final String? brandId;
  final String title;
  final String slug;
  final String? description;
  final String? shortDescription;
  final String jewelleryType;
  final String? material;
  final String? purity;
  final String? gender;
  final String? occasion;
  final String status;
  final bool featured;
  final String currency;
  final double basePrice;
  final double? comparePrice;
  final int? minOrderQuantity;
  final double ratingAverage;
  final int ratingCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPublished => ProductStatus.isPublished(status);

  factory SellerProduct.fromMap(Map<String, dynamic> map) {
    return SellerProduct(
      id: map['id'] as String,
      sellerId: map['seller_id'] as String,
      brandId: map['brand_id'] as String?,
      title: map['title'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      shortDescription: map['short_description'] as String?,
      jewelleryType: map['jewellery_type'] as String,
      material: map['material'] as String?,
      purity: map['purity'] as String?,
      gender: map['gender'] as String?,
      occasion: map['occasion'] as String?,
      status: map['status'] as String? ?? ProductStatus.draft,
      featured: map['featured'] as bool? ?? false,
      currency: map['currency'] as String? ?? 'PKR',
      basePrice: parseDouble(map['base_price']),
      comparePrice: parseDoubleOrNull(map['compare_price']),
      minOrderQuantity: map['min_order_quantity'] == null
          ? null
          : parseInt(map['min_order_quantity']),
      ratingAverage: parseDouble(map['rating_average']),
      ratingCount: parseInt(map['rating_count']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}

/// A seller product with its assigned category ids (for the editor).
class SellerProductDetail {
  const SellerProductDetail({
    required this.product,
    this.categoryIds = const [],
  });

  final SellerProduct product;
  final List<String> categoryIds;
}
