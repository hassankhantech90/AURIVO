import '../../../../core/supabase/supabase_database_service.dart';
import '../../domain/entities/seller_variant.dart';
import '../../domain/repositories/seller_variant_repository.dart';
import '../seller_product_failure_mapper.dart';

/// Supabase-backed [SellerVariantRepository]. RLS
/// (`product_variants_seller_all_own`) restricts every write to the seller who
/// owns the parent product; ownership is never supplied by the UI.
class SupabaseSellerVariantRepository implements SellerVariantRepository {
  SupabaseSellerVariantRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _table = 'product_variants';

  @override
  Future<List<SellerVariant>> getVariants(String productId) async {
    try {
      final rows = await _database.list(
        table: _table,
        filters: {'product_id': productId},
        orderBy: 'created_at',
      );
      return rows
          .where((r) => r['deleted_at'] == null)
          .map(SellerVariant.fromMap)
          .toList();
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<SellerVariant> createVariant(
    String productId,
    VariantDraft draft,
  ) async {
    try {
      final row = await _database.insert(
        table: _table,
        values: {'product_id': productId, ..._columns(draft)},
      );
      return SellerVariant.fromMap(row);
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<SellerVariant> updateVariant(String id, VariantDraft draft) async {
    try {
      final row = await _database.update(
        table: _table,
        values: _columns(draft),
        matchColumn: 'id',
        matchValue: id,
      );
      return SellerVariant.fromMap(row);
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<void> softDelete(String id) async {
    try {
      await _database.update(
        table: _table,
        values: {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  Map<String, dynamic> _columns(VariantDraft d) {
    return <String, dynamic>{
      'sku': d.sku.trim(),
      'price': d.price,
      'currency': d.currency,
      'stock_quantity': d.stockQuantity,
      'low_stock_threshold': d.lowStockThreshold,
      'is_active': d.isActive,
      'compare_price': ?d.comparePrice,
      'weight_grams': ?d.weightGrams,
      'barcode': ?_clean(d.barcode),
    };
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
