import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_seller_variant_repository.dart';
import '../domain/entities/seller_variant.dart';
import '../domain/repositories/seller_variant_repository.dart';
import 'seller_providers.dart' show SellerDataState, SellerViewStatus;

/// Repository binding for seller variant management.
final sellerVariantRepositoryProvider = Provider<SellerVariantRepository>((
  ref,
) {
  const service = SupabaseService();
  return SupabaseSellerVariantRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

/// Variants of a product, keyed by product id, with create/edit/delete.
final productVariantsProvider =
    StateNotifierProvider.family<
      ProductVariantsNotifier,
      SellerDataState<List<SellerVariant>>,
      String
    >((ref, productId) {
      return ProductVariantsNotifier(
        ref.watch(sellerVariantRepositoryProvider),
        productId,
      );
    });

class ProductVariantsNotifier
    extends StateNotifier<SellerDataState<List<SellerVariant>>> {
  ProductVariantsNotifier(this._repository, this._productId)
    : super(const SellerDataState<List<SellerVariant>>());

  final SellerVariantRepository _repository;
  final String _productId;

  Future<void> load() async {
    state = state.copyWith(
      status: SellerViewStatus.loading,
      clearMessage: true,
    );
    try {
      final variants = await _repository.getVariants(_productId);
      state = SellerDataState(status: SellerViewStatus.success, data: variants);
    } catch (error) {
      state = state.copyWith(
        status: SellerViewStatus.failure,
        message: error.toString(),
      );
    }
  }

  Future<String?> create(VariantDraft draft) =>
      _mutate(() => _repository.createVariant(_productId, draft));

  Future<String?> update(String id, VariantDraft draft) =>
      _mutate(() => _repository.updateVariant(id, draft));

  Future<String?> remove(String id) =>
      _mutate(() => _repository.softDelete(id));

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
