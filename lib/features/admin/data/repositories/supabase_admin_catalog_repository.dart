import '../../../../core/supabase/supabase_database_service.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../products/domain/entities/attribute.dart';
import '../../../products/domain/entities/brand.dart';
import '../../domain/repositories/admin_catalog_repository.dart';
import '../admin_failure_mapper.dart';

/// Supabase-backed [AdminCatalogRepository]. Uses the `*_admin_all` RLS arm; it
/// never bypasses security. Lists fetch every row the admin can see and drop
/// soft-deleted rows client-side (the shared query helper only supports equality
/// filters, not `IS NULL`).
class SupabaseAdminCatalogRepository implements AdminCatalogRepository {
  SupabaseAdminCatalogRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const _categories = 'categories';
  static const _brands = 'brands';
  static const _attributes = 'attributes';
  static const _attributeValues = 'attribute_values';

  String get _now => DateTime.now().toUtc().toIso8601String();

  List<Map<String, dynamic>> _live(List<Map<String, dynamic>> rows) =>
      rows.where((r) => r['deleted_at'] == null).toList();

  // Categories ---------------------------------------------------------------

  @override
  Future<List<Category>> listCategories() async {
    try {
      final rows = await _database.list(
        table: _categories,
        orderBy: 'sort_order',
      );
      return _live(rows).map(Category.fromMap).toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<Category> createCategory({
    required String name,
    required String slug,
    String? parentId,
    String? description,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    try {
      final row = await _database.insert(
        table: _categories,
        values: {
          'name': name.trim(),
          'slug': slug.trim(),
          'parent_id': ?parentId,
          'description': ?description,
          'sort_order': sortOrder,
          'is_active': isActive,
        },
      );
      return Category.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<Category> updateCategory({
    required String id,
    String? name,
    String? slug,
    String? parentId,
    bool clearParent = false,
    String? description,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final values = <String, dynamic>{
        'name': ?name?.trim(),
        'slug': ?slug?.trim(),
        if (clearParent || parentId != null) 'parent_id': parentId,
        'description': ?description?.trim(),
        'sort_order': ?sortOrder,
        'is_active': ?isActive,
      };
      final row = await _database.update(
        table: _categories,
        values: values,
        matchColumn: 'id',
        matchValue: id,
      );
      return Category.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      await _database.update(
        table: _categories,
        values: {'deleted_at': _now, 'is_active': false},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  // Brands -------------------------------------------------------------------

  @override
  Future<List<Brand>> listBrands() async {
    try {
      final rows = await _database.list(table: _brands, orderBy: 'name');
      return _live(rows).map(Brand.fromMap).toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<Brand> createBrand({
    required String name,
    required String slug,
    String? description,
    String status = 'active',
  }) async {
    try {
      final row = await _database.insert(
        table: _brands,
        values: {
          'name': name.trim(),
          'slug': slug.trim(),
          'description': ?description,
          'status': status,
        },
      );
      return Brand.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<Brand> updateBrand({
    required String id,
    String? name,
    String? slug,
    String? description,
    String? status,
  }) async {
    try {
      final values = <String, dynamic>{
        'name': ?name?.trim(),
        'slug': ?slug?.trim(),
        'description': ?description?.trim(),
        'status': ?status,
      };
      final row = await _database.update(
        table: _brands,
        values: values,
        matchColumn: 'id',
        matchValue: id,
      );
      return Brand.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteBrand(String id) async {
    try {
      await _database.update(
        table: _brands,
        values: {'deleted_at': _now, 'status': 'archived'},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  // Attributes ---------------------------------------------------------------

  @override
  Future<List<Attribute>> listAttributes() async {
    try {
      final rows = await _database.list(table: _attributes, orderBy: 'name');
      return _live(rows).map(Attribute.fromMap).toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<Attribute> createAttribute({
    required String name,
    required String slug,
    String dataType = 'text',
    String? unit,
    bool isFilterable = true,
  }) async {
    try {
      final row = await _database.insert(
        table: _attributes,
        values: {
          'name': name.trim(),
          'slug': slug.trim(),
          'data_type': dataType,
          'unit': ?unit,
          'is_filterable': isFilterable,
        },
      );
      return Attribute.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<Attribute> updateAttribute({
    required String id,
    String? name,
    String? slug,
    String? dataType,
    String? unit,
    bool? isFilterable,
  }) async {
    try {
      final values = <String, dynamic>{
        'name': ?name?.trim(),
        'slug': ?slug?.trim(),
        'data_type': ?dataType,
        'unit': ?unit?.trim(),
        'is_filterable': ?isFilterable,
      };
      final row = await _database.update(
        table: _attributes,
        values: values,
        matchColumn: 'id',
        matchValue: id,
      );
      return Attribute.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteAttribute(String id) async {
    try {
      await _database.update(
        table: _attributes,
        values: {'deleted_at': _now},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  // Attribute values ---------------------------------------------------------

  @override
  Future<List<AttributeValue>> listAttributeValues(String attributeId) async {
    try {
      final rows = await _database.list(
        table: _attributeValues,
        filters: {'attribute_id': attributeId},
        orderBy: 'sort_order',
      );
      return _live(rows).map(AttributeValue.fromMap).toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<AttributeValue> createAttributeValue({
    required String attributeId,
    required String value,
    String? normalizedValue,
    int sortOrder = 0,
  }) async {
    try {
      final row = await _database.insert(
        table: _attributeValues,
        values: {
          'attribute_id': attributeId,
          'value': value.trim(),
          'normalized_value': ?normalizedValue,
          'sort_order': sortOrder,
        },
      );
      return AttributeValue.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<AttributeValue> updateAttributeValue({
    required String id,
    String? value,
    String? normalizedValue,
    int? sortOrder,
  }) async {
    try {
      final values = <String, dynamic>{
        'value': ?value?.trim(),
        'normalized_value': ?normalizedValue?.trim(),
        'sort_order': ?sortOrder,
      };
      final row = await _database.update(
        table: _attributeValues,
        values: values,
        matchColumn: 'id',
        matchValue: id,
      );
      return AttributeValue.fromMap(row);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteAttributeValue(String id) async {
    try {
      await _database.update(
        table: _attributeValues,
        values: {'deleted_at': _now},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }
}
