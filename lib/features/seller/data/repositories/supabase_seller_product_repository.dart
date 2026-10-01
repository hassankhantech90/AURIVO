import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../products/domain/entities/brand.dart';
import '../../domain/entities/product_draft.dart';
import '../../domain/entities/seller_product.dart';
import '../../domain/repositories/seller_product_repository.dart';
import '../seller_product_failure_mapper.dart';

/// Supabase-backed [SellerProductRepository].
///
/// Every write is a direct, RLS-governed table operation. The seller's
/// `seller_profile_id` is resolved server-side from the current profile and set
/// as `products.seller_id` on create; the UI never supplies ownership. RLS
/// (`products_seller_*_own`, `product_categories_seller_all_own`) enforces that
/// a seller can only touch their own rows.
class SupabaseSellerProductRepository implements SellerProductRepository {
  SupabaseSellerProductRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _productsTable = 'products';
  static const String _productCategoriesTable = 'product_categories';
  static const String _sellerProfilesTable = 'seller_profiles';
  static const String _brandsTable = 'brands';
  static const String _categoriesTable = 'categories';

  @override
  Future<String?> mySellerProfileId() async {
    final profileId = await _currentProfileId();
    if (profileId == null) return null;
    final rows = await _database.list(
      table: _sellerProfilesTable,
      columns: 'id, profile_id',
      filters: {'profile_id': profileId},
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;
    // Not an owner: the store this user works for as staff, if any. The
    // server checks the catalogue permission on every write.
    final store = await _database.rpc(functionName: 'my_seller_store');
    return store is String && store.isNotEmpty ? store : null;
  }

  @override
  Future<List<SellerProduct>> getMyProducts({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final sellerId = await _requireSellerProfileId();
      final rows = await _database.list(
        table: _productsTable,
        filters: {'seller_id': sellerId},
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
        offset: offset,
      );
      // Hide soft-deleted rows (list has no IS NULL filter).
      return rows
          .where((r) => r['deleted_at'] == null)
          .map(SellerProduct.fromMap)
          .toList();
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<SellerProductDetail> getProduct(String id) async {
    try {
      final rows = await _database.list(
        table: _productsTable,
        filters: {'id': id},
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const Failure(message: 'Product not found.');
      }
      final categoryRows = await _database.list(
        table: _productCategoriesTable,
        columns: 'category_id',
        filters: {'product_id': id},
      );
      return SellerProductDetail(
        product: SellerProduct.fromMap(rows.first),
        categoryIds: categoryRows
            .map((r) => r['category_id'] as String)
            .toList(),
      );
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<SellerProduct> createProduct(ProductDraft draft) async {
    try {
      final sellerId = await _requireSellerProfileId();
      final row = await _database.insert(
        table: _productsTable,
        values: {'seller_id': sellerId, ..._draftColumns(draft)},
      );
      final product = SellerProduct.fromMap(row);
      await _replaceCategories(product.id, draft.categoryIds);
      return product;
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<SellerProduct> updateProduct(String id, ProductDraft draft) async {
    try {
      final row = await _database.update(
        table: _productsTable,
        values: _draftColumns(draft),
        matchColumn: 'id',
        matchValue: id,
      );
      await _replaceCategories(id, draft.categoryIds);
      return SellerProduct.fromMap(row);
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<SellerProduct> setPublished(String id, bool published) async {
    try {
      // Sellers can only submit for review (draft -> pending) or withdraw
      // (-> draft). Only an admin moves pending -> approved (enforced by the
      // products_moderation_guard trigger); the app never sets 'approved' here.
      final row = await _database.update(
        table: _productsTable,
        values: {
          'status': published ? ProductStatus.pending : ProductStatus.draft,
        },
        matchColumn: 'id',
        matchValue: id,
      );
      return SellerProduct.fromMap(row);
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<SellerProduct> setPaused(String id, bool paused) async {
    try {
      // products_moderation_guard allows a seller approved <-> paused only.
      final row = await _database.update(
        table: _productsTable,
        values: {
          'status': paused ? ProductStatus.paused : ProductStatus.approved,
        },
        matchColumn: 'id',
        matchValue: id,
      );
      return SellerProduct.fromMap(row);
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<void> softDelete(String id) async {
    try {
      await _database.update(
        table: _productsTable,
        values: {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<List<Brand>> getBrands() async {
    try {
      final rows = await _database.list(
        table: _brandsTable,
        filters: {'status': 'active'},
        orderBy: 'name',
      );
      return rows.map(Brand.fromMap).toList();
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<List<Category>> getCategories() async {
    try {
      final rows = await _database.list(
        table: _categoriesTable,
        filters: {'is_active': true},
        orderBy: 'sort_order',
      );
      return rows.map(Category.fromMap).toList();
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  // Helpers -------------------------------------------------------------------

  /// Replaces a product's category assignments with [categoryIds].
  Future<void> _replaceCategories(
    String productId,
    List<String> categoryIds,
  ) async {
    await _database.delete(
      table: _productCategoriesTable,
      matchColumn: 'product_id',
      matchValue: productId,
    );
    for (final categoryId in categoryIds) {
      await _database.insert(
        table: _productCategoriesTable,
        values: {'product_id': productId, 'category_id': categoryId},
      );
    }
  }

  Map<String, dynamic> _draftColumns(ProductDraft d) {
    // status / seller_id / rating are never set from a draft.
    return <String, dynamic>{
      'title': d.title.trim(),
      'slug': d.slug.trim(),
      'jewellery_type': d.jewelleryType,
      'base_price': d.basePrice,
      'currency': d.currency,
      'featured': d.featured,
      'brand_id': ?d.brandId,
      'compare_price': ?d.comparePrice,
      'min_order_quantity': ?d.minOrderQuantity,
      'description': ?_clean(d.description),
      'short_description': ?_clean(d.shortDescription),
      'material': ?_clean(d.material),
      'purity': ?_clean(d.purity),
      'gender': ?d.gender,
      'occasion': ?_clean(d.occasion),
      'certification': _clean(d.certification),
      'making_charges': d.makingCharges,
      'dimensions': _clean(d.dimensions),
      'is_returnable': d.isReturnable,
      'is_made_to_order': d.isMadeToOrder,
      'lead_time_days': d.leadTimeDays,
      'advance_payment_percent': d.advancePaymentPercent,
    };
  }

  Future<String> _requireSellerProfileId() async {
    final sellerId = await mySellerProfileId();
    if (sellerId == null) {
      throw const Failure(message: 'You do not have a seller store yet.');
    }
    return sellerId;
  }

  Future<String?> _currentProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) return result;
    return null;
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
