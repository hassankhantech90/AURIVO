import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../products/domain/entities/price_tier.dart';
import '../data/repositories/supabase_seller_tier_repository.dart';
import '../domain/entities/price_tier_draft.dart';
import '../domain/repositories/seller_tier_repository.dart';
import 'seller_providers.dart' show SellerDataState, SellerViewStatus;

/// Repository binding for seller wholesale-tier management.
final sellerTierRepositoryProvider = Provider<SellerTierRepository>((ref) {
  const service = SupabaseService();
  return SupabaseSellerTierRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

/// Wholesale price tiers of a product, keyed by product id, with
/// create/edit/delete.
final productTiersProvider =
    StateNotifierProvider.family<
      ProductTiersNotifier,
      SellerDataState<List<PriceTier>>,
      String
    >((ref, productId) {
      return ProductTiersNotifier(
        ref.watch(sellerTierRepositoryProvider),
        productId,
      );
    });

class ProductTiersNotifier
    extends StateNotifier<SellerDataState<List<PriceTier>>> {
  ProductTiersNotifier(this._repository, this._productId)
    : super(const SellerDataState<List<PriceTier>>());

  final SellerTierRepository _repository;
  final String _productId;

  Future<void> load() async {
    state = state.copyWith(
      status: SellerViewStatus.loading,
      clearMessage: true,
    );
    try {
      final tiers = await _repository.getTiers(_productId);
      state = SellerDataState(status: SellerViewStatus.success, data: tiers);
    } catch (error) {
      state = state.copyWith(
        status: SellerViewStatus.failure,
        message: error.toString(),
      );
    }
  }

  Future<String?> create(PriceTierDraft draft) =>
      _mutate(() => _repository.createTier(_productId, draft));

  Future<String?> update(String id, PriceTierDraft draft) =>
      _mutate(() => _repository.updateTier(id, draft));

  Future<String?> remove(String id) =>
      _mutate(() => _repository.deleteTier(id));

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
