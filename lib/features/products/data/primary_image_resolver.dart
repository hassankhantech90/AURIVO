import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_storage_service.dart';
import '../domain/entities/product.dart';

/// Resolves buyer-facing primary product images without per-card lookups.
///
/// A whole catalogue page is enriched with ONE `product_images` query: rows for
/// every product id are fetched together, the primary image is chosen per
/// product (first `is_primary`, else first by `sort_order`), and its storage
/// path is turned into a public URL locally via [SupabaseStorageService].
///
/// RLS on `product_images` is the sole visibility boundary, so only approved,
/// non-deleted images are ever returned — URLs are never built for paths the
/// query did not surface. The `product-images` bucket is public by design.
class PrimaryImageResolver {
  const PrimaryImageResolver({
    required SupabaseDatabaseService database,
    required SupabaseStorageService storage,
  }) : _database = database,
       _storage = storage;

  final SupabaseDatabaseService _database;
  final SupabaseStorageService _storage;

  static const String _bucket = 'product-images';
  static const String _table = 'product_images';

  // Only the columns needed to pick and resolve a primary image (no alt_text,
  // ids, or timestamps).
  static const String _columns =
      'product_id, storage_path, is_primary, sort_order';

  /// Public URL for a single storage [path]. This is a local string build with
  /// no network IO, so it is cheap and cache-free.
  String publicUrl(String path) =>
      _storage.getPublicUrl(bucket: _bucket, path: path);

  /// Maps each product id to its resolved primary-image public URL.
  ///
  /// Performs exactly ONE `product_images` query for the deduplicated [productIds]
  /// and returns `{}` — issuing no query — for empty input. Products with no
  /// visible image are simply absent from the map.
  Future<Map<String, String>> primaryImageUrls(
    Iterable<String> productIds,
  ) async {
    final ids = productIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};

    final rows = await _database.list(
      table: _table,
      columns: _columns,
      whereIn: {'product_id': List<Object>.from(ids)},
      orderBy: 'sort_order',
    );

    // Rows arrive in ascending sort_order. Keep the first row seen per product,
    // upgrading to the first `is_primary` row when one appears. Multiple primary
    // rows resolve to the first by sort_order (no schema validation here).
    final chosen = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final productId = row['product_id'] as String?;
      if (productId == null) continue;
      final existing = chosen[productId];
      if (existing == null) {
        chosen[productId] = row;
        continue;
      }
      final existingPrimary = existing['is_primary'] as bool? ?? false;
      final rowPrimary = row['is_primary'] as bool? ?? false;
      if (rowPrimary && !existingPrimary) chosen[productId] = row;
    }

    final urls = <String, String>{};
    for (final entry in chosen.entries) {
      final path = entry.value['storage_path'] as String?;
      if (path == null || path.isEmpty) continue;
      urls[entry.key] = publicUrl(path);
    }
    return urls;
  }

  /// Returns [products] with `primaryImageUrl` populated from a single batch
  /// image query.
  ///
  /// An empty list is returned untouched (no query). Imagery is optional: if the
  /// batch image query fails the catalogue still returns with null urls (the
  /// existing placeholder renders) rather than being made unusable. The caller's
  /// own product-query failure handling is unaffected — this only guards the
  /// image enrichment step.
  Future<List<Product>> enrich(List<Product> products) async {
    if (products.isEmpty) return products;
    try {
      final urls = await primaryImageUrls(products.map((p) => p.id));
      return products
          .map((p) => p.copyWith(primaryImageUrl: urls[p.id]))
          .toList();
    } catch (_) {
      return products;
    }
  }
}
