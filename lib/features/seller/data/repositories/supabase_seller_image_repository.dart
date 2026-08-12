import 'dart:math';
import 'dart:typed_data';

import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/supabase/supabase_storage_service.dart';
import '../../domain/entities/seller_image.dart';
import '../../domain/repositories/seller_image_repository.dart';
import '../seller_product_failure_mapper.dart';

/// Supabase-backed [SellerImageRepository]. Uploads go to the public
/// `product-images` bucket under `{product_id}/...`; the storage policies and
/// `product_images_seller_all_own` RLS both restrict writes to the seller who
/// owns the product. Ownership is never supplied by the UI.
class SupabaseSellerImageRepository implements SellerImageRepository {
  SupabaseSellerImageRepository({
    required SupabaseDatabaseService database,
    required SupabaseStorageService storage,
  }) : _database = database,
       _storage = storage;

  final SupabaseDatabaseService _database;
  final SupabaseStorageService _storage;

  static const String _bucket = 'product-images';
  static const String _table = 'product_images';

  @override
  Future<List<SellerImage>> getImages(String productId) async {
    try {
      final images = await _loadImages(productId);
      return images.map(_withUrl).toList();
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<SellerImage> uploadImage({
    required String productId,
    required Uint8List bytes,
    required String fileExtension,
    String? contentType,
    String? altText,
  }) async {
    try {
      final existing = await _loadImages(productId);
      final ext = fileExtension.replaceAll('.', '').toLowerCase();
      final path =
          '$productId/${DateTime.now().millisecondsSinceEpoch}-'
          '${Random().nextInt(1 << 32)}.$ext';

      await _storage.uploadImage(
        bucket: _bucket,
        path: path,
        bytes: bytes,
        contentType: contentType ?? _contentTypeFor(ext),
      );

      final row = await _database.insert(
        table: _table,
        values: {
          'product_id': productId,
          'storage_path': path,
          'image_type': 'gallery',
          'is_primary': existing.isEmpty, // first image becomes primary
          'sort_order': existing.length,
          'alt_text': ?_clean(altText),
        },
      );
      return _withUrl(SellerImage.fromMap(row));
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<void> setPrimary(String productId, String imageId) async {
    try {
      final images = await _loadImages(productId);
      for (final image in images) {
        if (image.isPrimary && image.id != imageId) {
          await _database.update(
            table: _table,
            values: {'is_primary': false},
            matchColumn: 'id',
            matchValue: image.id,
          );
        }
      }
      await _database.update(
        table: _table,
        values: {'is_primary': true},
        matchColumn: 'id',
        matchValue: imageId,
      );
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<void> reorder(String productId, List<String> orderedImageIds) async {
    try {
      for (var i = 0; i < orderedImageIds.length; i++) {
        await _database.update(
          table: _table,
          values: {'sort_order': i},
          matchColumn: 'id',
          matchValue: orderedImageIds[i],
        );
      }
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteImage(SellerImage image) async {
    try {
      await _storage.deleteImage(bucket: _bucket, path: image.storagePath);
      await _database.delete(
        table: _table,
        matchColumn: 'id',
        matchValue: image.id,
      );
      if (image.isPrimary) {
        final remaining = await _loadImages(image.productId);
        if (remaining.isNotEmpty) {
          await setPrimary(image.productId, remaining.first.id);
        }
      }
    } catch (error) {
      throw SellerProductFailureMapper.map(error);
    }
  }

  // Helpers -------------------------------------------------------------------

  /// Loads non-deleted images ordered primary-first, then by sort order.
  Future<List<SellerImage>> _loadImages(String productId) async {
    final rows = await _database.list(
      table: _table,
      filters: {'product_id': productId},
      orderBy: 'sort_order',
    );
    final images = rows
        .where((r) => r['deleted_at'] == null)
        .map(SellerImage.fromMap)
        .toList();
    images.sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return images;
  }

  SellerImage _withUrl(SellerImage image) => image.withPublicUrl(
    _storage.getPublicUrl(bucket: _bucket, path: image.storagePath),
  );

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
