import 'dart:typed_data';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_storage_service.dart';
import '../../../core/utils/failure.dart';
import '../domain/entities/cms_entities.dart';

/// CMS content: public reads of live banners / published pages (RLS) and
/// admin CRUD (admin-only RLS). Banner images live in the public
/// `cms-media` bucket.
abstract class CmsRepository {
  Future<List<CmsBanner>> liveBanners();
  Future<List<CmsPage>> publishedPages({String? kind});
  Future<CmsPage?> pageBySlug(String slug);

  // Admin
  Future<List<CmsBanner>> allBanners();
  Future<List<CmsPage>> allPages();
  Future<void> saveBanner(Map<String, dynamic> values, {String? id});
  Future<void> deleteBanner(String id);
  Future<void> savePage(Map<String, dynamic> values, {String? id});
  Future<void> deletePage(String id);
  Future<String> uploadBannerImage(Uint8List bytes, String extension);
}

class SupabaseCmsRepository implements CmsRepository {
  const SupabaseCmsRepository({
    required SupabaseDatabaseService database,
    required SupabaseStorageService storage,
  }) : _database = database,
       _storage = storage;

  final SupabaseDatabaseService _database;
  final SupabaseStorageService _storage;

  static const _bucket = 'cms-media';

  Future<T> _guard<T>(Future<T> Function() body, String failure) async {
    try {
      return await body();
    } catch (_) {
      throw Failure(message: failure);
    }
  }

  CmsBanner _banner(Map<String, dynamic> row) {
    final path = row['image_path'] as String?;
    return CmsBanner.fromMap(
      row,
      imageUrl: path == null || path.isEmpty
          ? null
          : _storage.getPublicUrl(bucket: _bucket, path: path),
    );
  }

  @override
  Future<List<CmsBanner>> liveBanners() => _guard(() async {
    // RLS returns only active banners inside their schedule.
    final rows = await _database.list(table: 'cms_banners', orderBy: 'sort_order');
    return rows.map(_banner).toList();
  }, 'Could not load banners.');

  @override
  Future<List<CmsPage>> publishedPages({String? kind}) => _guard(() async {
    final rows = await _database.list(
      table: 'cms_pages',
      filters: {'kind': ?kind},
      orderBy: 'sort_order',
    );
    return rows.map(CmsPage.fromMap).toList();
  }, 'Could not load help content.');

  @override
  Future<CmsPage?> pageBySlug(String slug) => _guard(() async {
    final rows = await _database.list(
      table: 'cms_pages',
      filters: {'slug': slug},
      limit: 1,
    );
    return rows.isEmpty ? null : CmsPage.fromMap(rows.first);
  }, 'Could not load this page.');

  @override
  Future<List<CmsBanner>> allBanners() => liveBanners();

  @override
  Future<List<CmsPage>> allPages() => publishedPages();

  @override
  Future<void> saveBanner(Map<String, dynamic> values, {String? id}) => _guard(
    () => id == null
        ? _database.insertVoid(table: 'cms_banners', values: values)
        : _database.update(
            table: 'cms_banners',
            values: values,
            matchColumn: 'id',
            matchValue: id,
          ),
    'Could not save the banner.',
  );

  @override
  Future<void> deleteBanner(String id) => _guard(
    () => _database.delete(table: 'cms_banners', matchColumn: 'id', matchValue: id),
    'Could not delete the banner.',
  );

  @override
  Future<void> savePage(Map<String, dynamic> values, {String? id}) => _guard(
    () => id == null
        ? _database.insertVoid(table: 'cms_pages', values: values)
        : _database.update(
            table: 'cms_pages',
            values: values,
            matchColumn: 'id',
            matchValue: id,
          ),
    'Could not save the page. Check the URL slug is unique.',
  );

  @override
  Future<void> deletePage(String id) => _guard(
    () => _database.delete(table: 'cms_pages', matchColumn: 'id', matchValue: id),
    'Could not delete the page.',
  );

  @override
  Future<String> uploadBannerImage(Uint8List bytes, String extension) =>
      _guard(() async {
        final ext = extension.toLowerCase().replaceAll('.', '');
        final path = 'banners/${DateTime.now().microsecondsSinceEpoch}.$ext';
        await _storage.uploadImage(
          bucket: _bucket,
          path: path,
          bytes: bytes,
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        );
        return path;
      }, 'Could not upload the image.');
}
