import 'dart:typed_data';

import 'package:aurivo/features/seller/domain/entities/seller_image.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_image_repository.dart';
import 'package:aurivo/features/seller/presentation/seller_images_page.dart';
import 'package:aurivo/features/seller/providers/seller_image_providers.dart';
import 'package:flutter/material.dart';
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
  final List<SellerImage> images;

  @override
  Future<List<SellerImage>> getImages(String productId) async => images;

  @override
  Future<SellerImage> uploadImage({
    required String productId,
    required Uint8List bytes,
    required String fileExtension,
    String? contentType,
    String? altText,
  }) async => _image();

  @override
  Future<void> setPrimary(String productId, String imageId) async {}

  @override
  Future<void> reorder(String productId, List<String> orderedImageIds) async {}

  @override
  Future<void> deleteImage(SellerImage image) async {}
}

Widget _wrap(SellerImageRepository repo) {
  return ProviderScope(
    overrides: [sellerImageRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: SellerImagesPage(productId: 'prod-1')),
  );
}

void main() {
  testWidgets('empty state when a product has no images', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pumpAndSettle();
    expect(find.text('No images yet'), findsOneWidget);
    expect(find.text('Add image'), findsOneWidget);
  });

  testWidgets('renders images with a primary badge and set-primary action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _FakeRepo(
          images: [
            _image(id: 'a', primary: true),
            _image(id: 'b'),
          ],
        ),
      ),
    );
    // Not pumpAndSettle: the network thumbnails never "settle" in tests.
    await tester.pump(); // run the post-frame load
    await tester.pump(const Duration(milliseconds: 50)); // apply provider state
    expect(find.text('Primary'), findsOneWidget); // the primary image
    expect(find.text('Set as primary'), findsOneWidget); // the other image
  });
}
