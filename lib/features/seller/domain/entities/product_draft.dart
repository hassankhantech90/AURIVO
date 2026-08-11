/// Editable product fields captured by the seller product form, shared by
/// create and update. `seller_id`, `status`, and rating fields are NOT part of
/// this draft — they are set/owned server-side (ownership) or via the dedicated
/// publish action.
class ProductDraft {
  const ProductDraft({
    required this.title,
    required this.slug,
    required this.jewelleryType,
    required this.basePrice,
    this.currency = 'PKR',
    this.comparePrice,
    this.description,
    this.shortDescription,
    this.material,
    this.purity,
    this.gender,
    this.occasion,
    this.brandId,
    this.minOrderQuantity,
    this.featured = false,
    this.categoryIds = const [],
  });

  final String title;
  final String slug;
  final String jewelleryType;
  final double basePrice;
  final String currency;
  final double? comparePrice;
  final String? description;
  final String? shortDescription;
  final String? material;
  final String? purity;
  final String? gender;
  final String? occasion;
  final String? brandId;
  final int? minOrderQuantity;
  final bool featured;
  final List<String> categoryIds;
}
