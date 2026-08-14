import '../../../../core/supabase/supabase_database_service.dart';
import '../../../profile/domain/entities/seller_profile.dart';
import '../../../seller/domain/entities/seller_product.dart';
import '../../domain/repositories/admin_repository.dart';
import '../admin_failure_mapper.dart';

/// Supabase-backed [AdminRepository]. Uses the admin arm of the existing RLS
/// policies; it never bypasses security and trusts no id from the UI beyond the
/// row being moderated.
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _sellerProfilesTable = 'seller_profiles';
  static const String _productsTable = 'products';

  @override
  Future<bool> isAdmin() async {
    try {
      final result = await _database.rpc(
        functionName: 'has_role',
        params: {'role_name': 'admin'},
      );
      return result == true;
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<List<SellerProfile>> getPendingSellers() async {
    try {
      final rows = await _database.list(
        table: _sellerProfilesTable,
        filters: {'verification_status': 'pending'},
        orderBy: 'created_at',
      );
      return rows.map(SellerProfile.fromMap).toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> setSellerVerification({
    required String sellerId,
    required String status,
  }) async {
    try {
      await _database.update(
        table: _sellerProfilesTable,
        values: {'verification_status': status},
        matchColumn: 'id',
        matchValue: sellerId,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<List<SellerProduct>> getPendingProducts() async {
    try {
      final rows = await _database.list(
        table: _productsTable,
        filters: {'status': 'pending'},
        orderBy: 'created_at',
      );
      return rows.map(SellerProduct.fromMap).toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> setProductStatus({
    required String productId,
    required String status,
  }) async {
    try {
      await _database.update(
        table: _productsTable,
        values: {'status': status},
        matchColumn: 'id',
        matchValue: productId,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }
}
