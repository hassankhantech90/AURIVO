import 'entity_parsing.dart';

/// Seller storefront profile (`public.seller_profiles`).
class SellerProfile {
  const SellerProfile({
    required this.id,
    required this.profileId,
    required this.storeName,
    required this.slug,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.city,
    this.verificationStatus = 'pending',
    this.isWholesaleEnabled = false,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.commissionRate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String profileId;
  final String storeName;
  final String slug;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String? city;
  final String verificationStatus;
  final bool isWholesaleEnabled;
  final double ratingAverage;
  final int ratingCount;
  final double? commissionRate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SellerProfile.fromMap(Map<String, dynamic> map) {
    return SellerProfile(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      storeName: map['store_name'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      logoUrl: map['logo_url'] as String?,
      bannerUrl: map['banner_url'] as String?,
      city: map['city'] as String?,
      verificationStatus: map['verification_status'] as String? ?? 'pending',
      isWholesaleEnabled: map['is_wholesale_enabled'] as bool? ?? false,
      ratingAverage: (map['rating_average'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['rating_count'] as num?)?.toInt() ?? 0,
      commissionRate: (map['commission_rate'] as num?)?.toDouble(),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
