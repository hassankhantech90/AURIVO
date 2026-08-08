/// Jewellery brand (`public.brands`). Only `active` brands are publicly
/// readable under RLS.
class Brand {
  const Brand({
    required this.id,
    required this.name,
    required this.slug,
    this.logoPath,
    this.description,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String slug;
  final String? logoPath;
  final String? description;
  final String status;

  factory Brand.fromMap(Map<String, dynamic> map) {
    return Brand(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      logoPath: map['logo_path'] as String?,
      description: map['description'] as String?,
      status: map['status'] as String? ?? 'active',
    );
  }
}
