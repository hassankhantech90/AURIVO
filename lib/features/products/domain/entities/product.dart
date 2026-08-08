import '../../../../core/utils/db_parsing.dart';

/// Buyer-facing catalogue product (`public.products`).
///
/// Only `approved`, non-deleted products are publicly readable under RLS, so
/// the moderation `status` and `deleted_at` fields are intentionally not
/// surfaced here.
class Product {
  const Product({
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
  final bool featured;
  final String currency;
  final double basePrice;
  final double? comparePrice;
  final int? minOrderQuantity;
  final double ratingAverage;
  final int ratingCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
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
