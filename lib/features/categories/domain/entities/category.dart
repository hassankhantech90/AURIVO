import '../../../../core/utils/db_parsing.dart';

/// Catalogue category (`public.categories`). Supports a parent/child tree via
/// [parentId] (null = root/top-level category).
class Category {
  const Category({
    required this.id,
    this.parentId,
    required this.name,
    required this.slug,
    this.imagePath,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String? imagePath;
  final String? description;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isRoot => parentId == null;

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      parentId: map['parent_id'] as String?,
      name: map['name'] as String,
      slug: map['slug'] as String,
      imagePath: map['image_path'] as String?,
      description: map['description'] as String?,
      sortOrder: parseInt(map['sort_order']),
      isActive: map['is_active'] as bool? ?? true,
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
