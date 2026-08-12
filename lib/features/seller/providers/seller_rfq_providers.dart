import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../wholesale/domain/entities/rfq.dart';
import '../data/repositories/supabase_seller_rfq_repository.dart';
import '../domain/entities/quote_draft.dart';
import '../domain/entities/seller_rfq_view.dart';
import '../domain/repositories/seller_rfq_repository.dart';
import 'seller_providers.dart' show SellerDataState, SellerViewStatus;

/// Repository binding for the seller RFQ/quote surfaces.
final sellerRfqRepositoryProvider = Provider<SellerRfqRepository>((ref) {
  const service = SupabaseService();
  return SupabaseSellerRfqRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

// Seller RFQ inbox ------------------------------------------------------------

final sellerRfqInboxProvider =
    StateNotifierProvider<SellerRfqInboxNotifier, SellerDataState<List<Rfq>>>((
      ref,
    ) {
      return SellerRfqInboxNotifier(ref.watch(sellerRfqRepositoryProvider));
    });

class SellerRfqInboxNotifier extends StateNotifier<SellerDataState<List<Rfq>>> {
  SellerRfqInboxNotifier(this._repository)
    : super(const SellerDataState<List<Rfq>>());

  final SellerRfqRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      status: SellerViewStatus.loading,
      clearMessage: true,
    );
    try {
      final rfqs = await _repository.getInboxRfqs();
      state = SellerDataState(status: SellerViewStatus.success, data: rfqs);
    } catch (error) {
      state = state.copyWith(
        status: SellerViewStatus.failure,
        message: error.toString(),
      );
    }
  }
}

// Seller RFQ detail (+ my quote) ---------------------------------------------

final sellerRfqDetailProvider =
    StateNotifierProvider.family<
      SellerRfqDetailNotifier,
      SellerDataState<SellerRfqView>,
      String
    >((ref, rfqId) {
      return SellerRfqDetailNotifier(
        ref.watch(sellerRfqRepositoryProvider),
        rfqId,
      );
    });

class SellerRfqDetailNotifier
    extends StateNotifier<SellerDataState<SellerRfqView>> {
  SellerRfqDetailNotifier(this._repository, this._rfqId)
    : super(const SellerDataState<SellerRfqView>());

  final SellerRfqRepository _repository;
  final String _rfqId;

  Future<void> load() async {
    state = state.copyWith(
      status: SellerViewStatus.loading,
      clearMessage: true,
    );
    try {
      final rfq = await _repository.getRfq(_rfqId);
      final myQuote = await _repository.getMyQuoteForRfq(_rfqId);
      state = SellerDataState(
        status: SellerViewStatus.success,
        data: SellerRfqView(rfq: rfq, myQuote: myQuote),
      );
    } catch (error) {
      state = state.copyWith(
        status: SellerViewStatus.failure,
        message: error.toString(),
      );
    }
  }

  /// Creates or updates the seller's quote for this RFQ, then refreshes.
  /// Returns null on success or a user-facing message on failure.
  Future<String?> submitQuote(QuoteDraft draft) async {
    final existing = state.data?.myQuote;
    try {
      if (existing != null) {
        await _repository.updateQuote(existing.id, draft);
      } else {
        await _repository.createQuote(_rfqId, draft);
      }
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> deleteQuote() async {
    final existing = state.data?.myQuote;
    if (existing == null) return null;
    try {
      await _repository.deleteQuote(existing.id);
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
