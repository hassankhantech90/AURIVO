import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../categories/domain/entities/category.dart';
import '../../products/domain/entities/attribute.dart';
import '../../products/domain/entities/brand.dart';
import '../data/repositories/supabase_admin_catalog_repository.dart';
import '../domain/repositories/admin_catalog_repository.dart';
import 'admin_providers.dart' show AdminListState, AdminStatus;

/// Repository binding (lazy service — stays test-safe without an initialized
/// Supabase client).
final adminCatalogRepositoryProvider = Provider<AdminCatalogRepository>((ref) {
  return SupabaseAdminCatalogRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

// Categories ------------------------------------------------------------------

final adminCategoriesProvider =
    StateNotifierProvider<AdminCategoriesNotifier, AdminListState<Category>>((
      ref,
    ) {
      return AdminCategoriesNotifier(ref.watch(adminCatalogRepositoryProvider));
    });

class AdminCategoriesNotifier extends StateNotifier<AdminListState<Category>> {
  AdminCategoriesNotifier(this._repository)
    : super(const AdminListState<Category>());

  final AdminCatalogRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      state = AdminListState(
        status: AdminStatus.success,
        data: await _repository.listCategories(),
      );
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }

  Future<String?> save({
    String? id,
    required String name,
    required String slug,
    String? parentId,
    String? description,
    required int sortOrder,
    required bool isActive,
  }) async {
    try {
      if (id == null) {
        await _repository.createCategory(
          name: name,
          slug: slug,
          parentId: parentId,
          description: description,
          sortOrder: sortOrder,
          isActive: isActive,
        );
      } else {
        await _repository.updateCategory(
          id: id,
          name: name,
          slug: slug,
          parentId: parentId,
          clearParent: parentId == null,
          description: description,
          sortOrder: sortOrder,
          isActive: isActive,
        );
      }
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> remove(String id) async {
    try {
      await _repository.deleteCategory(id);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}

// Brands ----------------------------------------------------------------------

final adminBrandsProvider =
    StateNotifierProvider<AdminBrandsNotifier, AdminListState<Brand>>((ref) {
      return AdminBrandsNotifier(ref.watch(adminCatalogRepositoryProvider));
    });

class AdminBrandsNotifier extends StateNotifier<AdminListState<Brand>> {
  AdminBrandsNotifier(this._repository) : super(const AdminListState<Brand>());

  final AdminCatalogRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      state = AdminListState(
        status: AdminStatus.success,
        data: await _repository.listBrands(),
      );
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }

  Future<String?> save({
    String? id,
    required String name,
    required String slug,
    String? description,
    required String status,
  }) async {
    try {
      if (id == null) {
        await _repository.createBrand(
          name: name,
          slug: slug,
          description: description,
          status: status,
        );
      } else {
        await _repository.updateBrand(
          id: id,
          name: name,
          slug: slug,
          description: description,
          status: status,
        );
      }
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> remove(String id) async {
    try {
      await _repository.deleteBrand(id);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}

// Attributes ------------------------------------------------------------------

final adminAttributesProvider =
    StateNotifierProvider<AdminAttributesNotifier, AdminListState<Attribute>>((
      ref,
    ) {
      return AdminAttributesNotifier(ref.watch(adminCatalogRepositoryProvider));
    });

class AdminAttributesNotifier extends StateNotifier<AdminListState<Attribute>> {
  AdminAttributesNotifier(this._repository)
    : super(const AdminListState<Attribute>());

  final AdminCatalogRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      state = AdminListState(
        status: AdminStatus.success,
        data: await _repository.listAttributes(),
      );
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }

  Future<String?> save({
    String? id,
    required String name,
    required String slug,
    required String dataType,
    String? unit,
    required bool isFilterable,
  }) async {
    try {
      if (id == null) {
        await _repository.createAttribute(
          name: name,
          slug: slug,
          dataType: dataType,
          unit: unit,
          isFilterable: isFilterable,
        );
      } else {
        await _repository.updateAttribute(
          id: id,
          name: name,
          slug: slug,
          dataType: dataType,
          unit: unit,
          isFilterable: isFilterable,
        );
      }
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> remove(String id) async {
    try {
      await _repository.deleteAttribute(id);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}

// Attribute values (per attribute) --------------------------------------------

final adminAttributeValuesProvider =
    StateNotifierProvider.family<
      AdminAttributeValuesNotifier,
      AdminListState<AttributeValue>,
      String
    >((ref, attributeId) {
      return AdminAttributeValuesNotifier(
        repository: ref.watch(adminCatalogRepositoryProvider),
        attributeId: attributeId,
      );
    });

class AdminAttributeValuesNotifier
    extends StateNotifier<AdminListState<AttributeValue>> {
  AdminAttributeValuesNotifier({
    required AdminCatalogRepository repository,
    required String attributeId,
  }) : _repository = repository,
       _attributeId = attributeId,
       super(const AdminListState<AttributeValue>());

  final AdminCatalogRepository _repository;
  final String _attributeId;

  Future<void> load() async {
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      state = AdminListState(
        status: AdminStatus.success,
        data: await _repository.listAttributeValues(_attributeId),
      );
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }

  Future<String?> save({
    String? id,
    required String value,
    String? normalizedValue,
    required int sortOrder,
  }) async {
    try {
      if (id == null) {
        await _repository.createAttributeValue(
          attributeId: _attributeId,
          value: value,
          normalizedValue: normalizedValue,
          sortOrder: sortOrder,
        );
      } else {
        await _repository.updateAttributeValue(
          id: id,
          value: value,
          normalizedValue: normalizedValue,
          sortOrder: sortOrder,
        );
      }
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> remove(String id) async {
    try {
      await _repository.deleteAttributeValue(id);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
