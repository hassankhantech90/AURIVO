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
    this.primaryImageUrl,
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

  /// Resolved public URL of the primary catalogue image, populated by the data
  /// layer (not a `products` column). Null when the product has no visible
  /// image or imagery could not be resolved — the UI then shows a placeholder.
  final String? primaryImageUrl;

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

  /// Returns a copy with the given fields replaced. Used by the data layer to
  /// attach an enrichment-only [primaryImageUrl] after the catalogue query.
  Product copyWith({
    String? id,
    String? sellerId,
    String? brandId,
    String? title,
    String? slug,
    String? description,
    String? shortDescription,
    String? jewelleryType,
    String? material,
    String? purity,
    String? gender,
    String? occasion,
    bool? featured,
    String? currency,
    double? basePrice,
    double? comparePrice,
    int? minOrderQuantity,
    double? ratingAverage,
    int? ratingCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? primaryImageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      brandId: brandId ?? this.brandId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      jewelleryType: jewelleryType ?? this.jewelleryType,
      material: material ?? this.material,
      purity: purity ?? this.purity,
      gender: gender ?? this.gender,
      occasion: occasion ?? this.occasion,
      featured: featured ?? this.featured,
      currency: currency ?? this.currency,
      basePrice: basePrice ?? this.basePrice,
      comparePrice: comparePrice ?? this.comparePrice,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      primaryImageUrl: primaryImageUrl ?? this.primaryImageUrl,
    );
  }
}
