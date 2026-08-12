import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/supabase/supabase_storage_service.dart';
import '../data/repositories/supabase_seller_image_repository.dart';
import '../domain/entities/seller_image.dart';
import '../domain/repositories/seller_image_repository.dart';
import 'seller_providers.dart' show SellerDataState, SellerViewStatus;

/// Repository binding for seller product image management.
final sellerImageRepositoryProvider = Provider<SellerImageRepository>((ref) {
  const service = SupabaseService();
  return SupabaseSellerImageRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
    storage: const SupabaseStorageService(supabaseService: service),
  );
});

/// Images of a product, keyed by product id, with upload / primary / reorder /
/// delete.
final productImagesProvider =
    StateNotifierProvider.family<
      ProductImagesNotifier,
      SellerDataState<List<SellerImage>>,
      String
    >((ref, productId) {
      return ProductImagesNotifier(
        ref.watch(sellerImageRepositoryProvider),
        productId,
      );
    });

class ProductImagesNotifier
    extends StateNotifier<SellerDataState<List<SellerImage>>> {
  ProductImagesNotifier(this._repository, this._productId)
    : super(const SellerDataState<List<SellerImage>>());

  final SellerImageRepository _repository;
  final String _productId;

  Future<void> load() async {
    state = state.copyWith(
      status: SellerViewStatus.loading,
      clearMessage: true,
    );
    try {
      final images = await _repository.getImages(_productId);
      state = SellerDataState(status: SellerViewStatus.success, data: images);
    } catch (error) {
      state = state.copyWith(
        status: SellerViewStatus.failure,
        message: error.toString(),
      );
    }
  }

  Future<String?> upload({
    required Uint8List bytes,
    required String fileExtension,
    String? contentType,
  }) => _mutate(
    () => _repository.uploadImage(
      productId: _productId,
      bytes: bytes,
      fileExtension: fileExtension,
      contentType: contentType,
    ),
  );

  Future<String?> setPrimary(String imageId) =>
      _mutate(() => _repository.setPrimary(_productId, imageId));

  Future<String?> reorder(List<String> orderedImageIds) =>
      _mutate(() => _repository.reorder(_productId, orderedImageIds));

  Future<String?> remove(SellerImage image) =>
      _mutate(() => _repository.deleteImage(image));

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
