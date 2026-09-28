import '../../../../core/supabase/supabase_database_service.dart';
import '../../../products/domain/entities/price_tier.dart';
import '../../domain/entities/price_tier_draft.dart';
import '../../domain/repositories/seller_tier_repository.dart';
import '../seller_product_failure_mapper.dart';

/// Supabase-backed [SellerTierRepository]. RLS
/// (`product_price_tiers_seller_all_own`) restricts every write to the seller
/// who owns the parent product; ownership is never supplied by the UI.
class SupabaseSellerTierRepository implements SellerTierRepository {
  SupabaseSellerTierRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _table = 'product_price_tiers';

  @override
  Future<List<PriceTier>> getTiers(String productId) async {
    try {
      final rows = await _database.list(
        table: _table,
        filters: {'product_id': productId},
        orderBy: 'min_quantity',
      );
      return rows.map(PriceTier.fromMap).toList();
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<PriceTier> createTier(String productId, PriceTierDraft draft) async {
    try {
      final row = await _database.insert(
        table: _table,
        values: {'product_id': productId, ..._columns(draft)},
      );
      return PriceTier.fromMap(row);
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<PriceTier> updateTier(String id, PriceTierDraft draft) async {
    try {
      final row = await _database.update(
        table: _table,
        values: _columns(draft),
        matchColumn: 'id',
        matchValue: id,
      );
      return PriceTier.fromMap(row);
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteTier(String id) async {
    try {
      await _database.delete(table: _table, matchColumn: 'id', matchValue: id);
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  Map<String, dynamic> _columns(PriceTierDraft d) => <String, dynamic>{
    'min_quantity': d.minQuantity,
    'unit_price': d.unitPrice,
  };
}
