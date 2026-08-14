import '../../../categories/domain/entities/category.dart';
import '../../../products/domain/entities/attribute.dart';
import '../../../products/domain/entities/brand.dart';

/// Contract for admin catalog management (categories, brands, attributes and
/// their values). Every operation relies on the `*_admin_all` RLS policies
/// (`has_role('admin')`); non-admins are denied server-side. "Delete" is a soft
/// delete (sets `deleted_at`, plus deactivate/archive) so it stays reversible
/// and FK-safe. Lists exclude soft-deleted rows. Failures map to `Failure`.
abstract class AdminCatalogRepository {
  // Categories ---------------------------------------------------------------
  Future<List<Category>> listCategories();
  Future<Category> createCategory({
    required String name,
    required String slug,
    String? parentId,
    String? description,
    int sortOrder = 0,
    bool isActive = true,
  });
  Future<Category> updateCategory({
    required String id,
    String? name,
    String? slug,
    String? parentId,
    bool clearParent = false,
    String? description,
    int? sortOrder,
    bool? isActive,
  });
  Future<void> deleteCategory(String id);

  // Brands -------------------------------------------------------------------
  Future<List<Brand>> listBrands();
  Future<Brand> createBrand({
    required String name,
    required String slug,
    String? description,
    String status = 'active',
  });
  Future<Brand> updateBrand({
    required String id,
    String? name,
    String? slug,
    String? description,
    String? status,
  });
  Future<void> deleteBrand(String id);

  // Attributes ---------------------------------------------------------------
  Future<List<Attribute>> listAttributes();
  Future<Attribute> createAttribute({
    required String name,
    required String slug,
    String dataType = 'text',
    String? unit,
    bool isFilterable = true,
  });
  Future<Attribute> updateAttribute({
    required String id,
    String? name,
    String? slug,
    String? dataType,
    String? unit,
    bool? isFilterable,
  });
  Future<void> deleteAttribute(String id);

  // Attribute values ---------------------------------------------------------
  Future<List<AttributeValue>> listAttributeValues(String attributeId);
  Future<AttributeValue> createAttributeValue({
    required String attributeId,
    required String value,
    String? normalizedValue,
    int sortOrder = 0,
  });
  Future<AttributeValue> updateAttributeValue({
    required String id,
    String? value,
    String? normalizedValue,
    int? sortOrder,
  });
  Future<void> deleteAttributeValue(String id);
}
