import 'dart:typed_data';

import 'package:aurivo/features/seller/domain/entities/seller_image.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_image_repository.dart';
import 'package:aurivo/features/seller/providers/seller_image_providers.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart'
    show SellerViewStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerImage _image({String id = 'img-1', bool primary = false}) => SellerImage(
  id: id,
  productId: 'prod-1',
  storagePath: 'prod-1/$id.jpg',
  publicUrl: 'https://cdn.test/$id.jpg',
  isPrimary: primary,
);

class _FakeRepo implements SellerImageRepository {
  _FakeRepo({this.images = const []});
  List<SellerImage> images;
  int uploadCalls = 0;
  int setPrimaryCalls = 0;
  int reorderCalls = 0;
  int deleteCalls = 0;
  List<String>? lastOrder;

  @override
  Future<List<SellerImage>> getImages(String productId) async => images;

  @override
  Future<SellerImage> uploadImage({
    required String productId,
    required Uint8List bytes,
    required String fileExtension,
    String? contentType,
    String? altText,
  }) async {
    uploadCalls++;
    final created = _image(id: 'new', primary: images.isEmpty);
    images = [...images, created];
    return created;
  }

  @override
  Future<void> setPrimary(String productId, String imageId) async {
    setPrimaryCalls++;
    images = images
        .map((i) => _image(id: i.id, primary: i.id == imageId))
        .toList();
  }

  @override
  Future<void> reorder(String productId, List<String> orderedImageIds) async {
    reorderCalls++;
    lastOrder = orderedImageIds;
  }

  @override
  Future<void> deleteImage(SellerImage image) async {
    deleteCalls++;
    images = images.where((i) => i.id != image.id).toList();
  }
}

ProviderContainer _container(SellerImageRepository repo) {
  final container = ProviderContainer(
    overrides: [sellerImageRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load exposes images', () async {
    final container = _container(_FakeRepo(images: [_image(primary: true)]));
    await container.read(productImagesProvider('prod-1').notifier).load();
    final state = container.read(productImagesProvider('prod-1'));
    expect(state.status, SellerViewStatus.success);
    expect(state.data!.single.isPrimary, isTrue);
  });

  test('upload then reload', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final error = await container
        .read(productImagesProvider('prod-1').notifier)
        .upload(bytes: Uint8List.fromList([1]), fileExtension: 'jpg');
    expect(error, isNull);
    expect(repo.uploadCalls, 1);
    expect(container.read(productImagesProvider('prod-1')).data, isNotEmpty);
  });

  test('setPrimary and reorder and delete', () async {
    final repo = _FakeRepo(
      images: [
        _image(id: 'a', primary: true),
        _image(id: 'b'),
      ],
    );
    final container = _container(repo);
    final notifier = container.read(productImagesProvider('prod-1').notifier);
    await notifier.load();

    expect(await notifier.setPrimary('b'), isNull);
    expect(repo.setPrimaryCalls, 1);

    expect(await notifier.reorder(['b', 'a']), isNull);
    expect(repo.reorderCalls, 1);
    expect(repo.lastOrder, ['b', 'a']);

    expect(await notifier.remove(_image(id: 'a')), isNull);
    expect(repo.deleteCalls, 1);
  });
}
