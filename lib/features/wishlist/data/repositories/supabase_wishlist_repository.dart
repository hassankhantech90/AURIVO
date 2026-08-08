import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../../core/utils/failure.dart';
import '../../domain/entities/wishlist_item.dart';
import '../../domain/repositories/wishlist_repository.dart';
import '../wishlist_failure_mapper.dart';

/// Supabase-backed [WishlistRepository]. Relies entirely on the existing
/// authenticated-only RLS (rows scoped to `profile_id = current_profile_id()`);
/// it never bypasses security.
class SupabaseWishlistRepository implements WishlistRepository {
  SupabaseWishlistRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _table = 'wishlist';

  @override
  Future<List<WishlistItem>> getWishlist() async {
    try {
      final profileId = await _requireProfileId();
      final rows = await _database.list(
        table: _table,
        filters: {'profile_id': profileId},
        orderBy: 'created_at',
        ascending: false,
      );
      return rows.map(WishlistItem.fromMap).toList();
    } catch (error) {
      throw WishlistFailureMapper.map(error);
    }
  }

  @override
  Future<Set<String>> getWishlistedProductIds() async {
    final items = await getWishlist();
    return items.map((item) => item.productId).toSet();
  }

  @override
  Future<bool> isWishlisted(String productId) async {
    try {
      final profileId = await _requireProfileId();
      final existing = await _find(profileId, productId);
      return existing != null;
    } catch (error) {
      throw WishlistFailureMapper.map(error);
    }
  }

  @override
  Future<WishlistItem> add(String productId) async {
    try {
      final profileId = await _requireProfileId();
      final existing = await _find(profileId, productId);
      if (existing != null) return existing;

      try {
        final row = await _database.insert(
          table: _table,
          values: {'profile_id': profileId, 'product_id': productId},
        );
        return WishlistItem.fromMap(row);
      } on ex.AppSupabaseException catch (error) {
        // Concurrent insert hit the UNIQUE(profile_id, product_id) constraint.
        if (error.code == '23505') {
          final again = await _find(profileId, productId);
          if (again != null) return again;
        }
        rethrow;
      }
    } catch (error) {
      throw WishlistFailureMapper.map(error);
    }
  }

  @override
  Future<void> remove(String productId) async {
    try {
      // RLS scopes the delete to the current user's own rows, so matching on
      // product_id alone only affects this user's wishlist entry.
      await _database.delete(
        table: _table,
        matchColumn: 'product_id',
        matchValue: productId,
      );
    } catch (error) {
      throw WishlistFailureMapper.map(error);
    }
  }

  Future<WishlistItem?> _find(String profileId, String productId) async {
    final rows = await _database.list(
      table: _table,
      filters: {'profile_id': profileId, 'product_id': productId},
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WishlistItem.fromMap(rows.first);
  }

  Future<String> _requireProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) {
      return result;
    }
    throw const Failure(message: 'Please sign in to use your wishlist.');
  }
}
