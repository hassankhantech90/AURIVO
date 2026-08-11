import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../categories/domain/entities/category.dart';
import '../../products/domain/entities/brand.dart';
import '../data/repositories/supabase_seller_product_repository.dart';
import '../domain/entities/product_draft.dart';
import '../domain/entities/seller_product.dart';
import '../domain/repositories/seller_product_repository.dart';
import 'seller_providers.dart' show SellerDataState, SellerViewStatus;

/// Repository binding for seller product management.
final sellerProductRepositoryProvider = Provider<SellerProductRepository>((
  ref,
) {
  const service = SupabaseService();
  return SupabaseSellerProductRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

/// The current user's seller-profile id (null if not a seller) — used to gate
/// the seller dashboard.
final mySellerProfileIdProvider = FutureProvider<String?>((ref) {
  return ref.watch(sellerProductRepositoryProvider).mySellerProfileId();
});

/// Active brands / categories for the product form.
final sellerBrandsProvider = FutureProvider<List<Brand>>((ref) {
  return ref.watch(sellerProductRepositoryProvider).getBrands();
});

final sellerCategoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(sellerProductRepositoryProvider).getCategories();
});

// My products list + mutations ------------------------------------------------

final myProductsProvider =
    StateNotifierProvider<
      MyProductsNotifier,
      SellerDataState<List<SellerProduct>>
    >((ref) {
      return MyProductsNotifier(ref.watch(sellerProductRepositoryProvider));
    });

class MyProductsNotifier
    extends StateNotifier<SellerDataState<List<SellerProduct>>> {
  MyProductsNotifier(this._repository)
    : super(const SellerDataState<List<SellerProduct>>());

  final SellerProductRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      status: SellerViewStatus.loading,
      clearMessage: true,
    );
    try {
      final products = await _repository.getMyProducts();
      state = SellerDataState(status: SellerViewStatus.success, data: products);
    } catch (error) {
      state = state.copyWith(
        status: SellerViewStatus.failure,
        message: error.toString(),
      );
    }
  }

  /// Creates a product then refreshes. Returns null on success or a message.
  Future<String?> create(ProductDraft draft) =>
      _mutate(() => _repository.createProduct(draft));

  Future<String?> update(String id, ProductDraft draft) =>
      _mutate(() => _repository.updateProduct(id, draft));

  Future<String?> setPublished(String id, bool published) =>
      _mutate(() => _repository.setPublished(id, published));

  Future<String?> softDelete(String id) =>
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

// Single product (editor) -----------------------------------------------------

final sellerProductDetailProvider =
    StateNotifierProvider.family<
      SellerProductDetailNotifier,
      SellerDataState<SellerProductDetail>,
      String
    >((ref, id) {
      return SellerProductDetailNotifier(
        ref.watch(sellerProductRepositoryProvider),
        id,
      );
    });

class SellerProductDetailNotifier
    extends StateNotifier<SellerDataState<SellerProductDetail>> {
  SellerProductDetailNotifier(this._repository, this._id)
    : super(const SellerDataState<SellerProductDetail>());

  final SellerProductRepository _repository;
  final String _id;

  Future<void> load() async {
    state = state.copyWith(
      status: SellerViewStatus.loading,
      clearMessage: true,
    );
    try {
      final detail = await _repository.getProduct(_id);
      state = SellerDataState(status: SellerViewStatus.success, data: detail);
    } catch (error) {
      state = state.copyWith(
        status: SellerViewStatus.failure,
        message: error.toString(),
      );
    }
  }
}
