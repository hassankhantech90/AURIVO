import '../../../../core/supabase/supabase_database_service.dart';
import '../../../products/domain/entities/product.dart';
import '../../../profile/domain/entities/seller_profile.dart';
import '../../domain/repositories/seller_repository.dart';
import '../seller_failure_mapper.dart';

/// Supabase-backed read-only [SellerRepository].
///
/// Relies entirely on the existing RLS for visibility: `seller_profiles` are
/// only publicly readable when `verification_status = 'verified'`, and
/// `products` only when `status = 'approved'` (both non-deleted). It never
/// bypasses security and performs no writes.
class SupabaseSellerRepository implements SellerRepository {
  SupabaseSellerRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _sellersTable = 'seller_profiles';
  static const String _productsTable = 'products';

  @override
  Future<List<SellerProfile>> getVerifiedSellers({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _database.list(
        table: _sellersTable,
        filters: {'verification_status': 'verified'},
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
        offset: offset,
      );
      return rows.map(SellerProfile.fromMap).toList();
    } catch (error) {
      throw SellerFailureMapper.map(error);
    }
  }

  @override
  Future<SellerProfile?> getSellerBySlug(String slug) async {
    try {
      final rows = await _database.list(
        table: _sellersTable,
        filters: {'slug': slug, 'verification_status': 'verified'},
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return SellerProfile.fromMap(rows.first);
    } catch (error) {
      throw SellerFailureMapper.map(error);
    }
  }

  @override
  Future<SellerProfile?> getSellerById(String id) async {
    try {
      final rows = await _database.list(
        table: _sellersTable,
        filters: {'id': id, 'verification_status': 'verified'},
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return SellerProfile.fromMap(rows.first);
    } catch (error) {
      throw SellerFailureMapper.map(error);
    }
  }

  @override
  Future<List<Product>> getSellerProducts(
    String sellerId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _database.list(
        table: _productsTable,
        filters: {'seller_id': sellerId, 'status': 'approved'},
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
        offset: offset,
      );
      return rows.map(Product.fromMap).toList();
    } catch (error) {
      throw SellerFailureMapper.map(error);
    }
  }
}
