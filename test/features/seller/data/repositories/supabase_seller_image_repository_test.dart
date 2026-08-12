import 'dart:typed_data';

import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/supabase/supabase_storage_service.dart';
import 'package:aurivo/features/seller/data/repositories/supabase_seller_image_repository.dart';
import 'package:aurivo/features/seller/domain/entities/seller_image.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> imageRow({
  String id = 'img-1',
  bool primary = false,
  int sort = 0,
  String path = 'prod-1/a.jpg',
  String? deletedAt,
}) => {
  'id': id,
  'product_id': 'prod-1',
  'storage_path': path,
  'image_type': 'gallery',
  'sort_order': sort,
  'is_primary': primary,
  'deleted_at': deletedAt,
};

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  List<Map<String, dynamic>> rows = const [];
  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<Map<String, Object?>> deleted = [];

  @override
  Future<List<Map<String, dynamic>>> list({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
    Map<String, List<Object>> whereIn = const {},
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async => rows;

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    inserted.add(values);
    return {'id': 'img-new', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    updated.add({'_match': '$matchColumn=$matchValue', ...values});
    return {...imageRow(id: matchValue as String), ...values};
  }

  @override
  Future<void> delete({
    required String table,
    required String matchColumn,
    required Object matchValue,
  }) async {
    deleted.add({matchColumn: matchValue});
  }
}

class _StubStorage extends SupabaseStorageService {
  _StubStorage() : super(supabaseService: const SupabaseService());

  final List<String> uploads = [];
  final List<String> removed = [];

  @override
  Future<String> uploadImage({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
    bool upsert = false,
  }) async {
    uploads.add('$bucket/$path');
    return path;
  }

  @override
  Future<void> deleteImage({
    required String bucket,
    required String path,
  }) async {
    removed.add('$bucket/$path');
  }

  @override
  String getPublicUrl({required String bucket, required String path}) =>
      'https://cdn.test/$bucket/$path';
}

void main() {
  late _StubDatabase db;
  late _StubStorage storage;
  late SupabaseSellerImageRepository repo;

  setUp(() {
    db = _StubDatabase();
    storage = _StubStorage();
    repo = SupabaseSellerImageRepository(database: db, storage: storage);
  });

  test('getImages fills public URLs, hides deleted, primary first', () async {
    db.rows = [
      imageRow(id: 'a', sort: 1),
      imageRow(id: 'b', primary: true, sort: 2),
      imageRow(id: 'c', sort: 0, deletedAt: '2026-01-01T00:00:00Z'),
    ];
    final images = await repo.getImages('prod-1');
    expect(images.map((i) => i.id), ['b', 'a']); // primary first, 'c' hidden
    expect(images.first.publicUrl, contains('product-images/'));
  });

  test('uploadImage uploads under {product_id}/ and inserts a row', () async {
    db.rows = const []; // no existing images -> becomes primary
    await repo.uploadImage(
      productId: 'prod-1',
      bytes: Uint8List.fromList([1, 2, 3]),
      fileExtension: 'png',
    );

    expect(storage.uploads.single, startsWith('product-images/prod-1/'));
    expect(storage.uploads.single, endsWith('.png'));
    final values = db.inserted.single;
    expect(values['product_id'], 'prod-1');
    expect(values['is_primary'], isTrue); // first image
    expect(values['sort_order'], 0);
    expect((values['storage_path'] as String).startsWith('prod-1/'), isTrue);
  });

  test('uploadImage is not primary when images already exist', () async {
    db.rows = [imageRow(id: 'a', primary: true)];
    await repo.uploadImage(
      productId: 'prod-1',
      bytes: Uint8List.fromList([1]),
      fileExtension: 'jpg',
    );
    expect(db.inserted.single['is_primary'], isFalse);
    expect(db.inserted.single['sort_order'], 1);
  });

  test('setPrimary unsets the old primary and sets the new one', () async {
    db.rows = [imageRow(id: 'a', primary: true), imageRow(id: 'b')];
    await repo.setPrimary('prod-1', 'b');
    // 'a' set false, 'b' set true.
    expect(
      db.updated.any((u) => u['_match'] == 'id=a' && u['is_primary'] == false),
      isTrue,
    );
    expect(
      db.updated.any((u) => u['_match'] == 'id=b' && u['is_primary'] == true),
      isTrue,
    );
  });

  test('reorder writes sequential sort_order per id', () async {
    await repo.reorder('prod-1', ['x', 'y', 'z']);
    expect(db.updated[0], {'_match': 'id=x', 'sort_order': 0});
    expect(db.updated[1], {'_match': 'id=y', 'sort_order': 1});
    expect(db.updated[2], {'_match': 'id=z', 'sort_order': 2});
  });

  test('deleteImage removes the object and the row', () async {
    db.rows = const []; // nothing remaining
    await repo.deleteImage(
      const SellerImage(
        id: 'img-1',
        productId: 'prod-1',
        storagePath: 'prod-1/a.jpg',
        isPrimary: false,
      ),
    );
    expect(storage.removed.single, 'product-images/prod-1/a.jpg');
    expect(db.deleted.single['id'], 'img-1');
  });

  test('deleting the primary promotes the next remaining image', () async {
    db.rows = [imageRow(id: 'b', sort: 1)]; // remaining after delete
    await repo.deleteImage(
      const SellerImage(
        id: 'a',
        productId: 'prod-1',
        storagePath: 'prod-1/a.jpg',
        isPrimary: true,
      ),
    );
    // 'b' promoted to primary.
    expect(
      db.updated.any((u) => u['_match'] == 'id=b' && u['is_primary'] == true),
      isTrue,
    );
  });
}
