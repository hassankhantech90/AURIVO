import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_rfq_repository.dart';
import '../domain/entities/rfq.dart';
import '../domain/entities/rfq_detail.dart';
import '../domain/repositories/rfq_repository.dart';

/// Repository binding for the wholesale/RFQ module (lazy services — stays
/// test-safe without an initialized Supabase client).
final rfqRepositoryProvider = Provider<RFQRepository>((ref) {
  const service = SupabaseService();
  return SupabaseRfqRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
  );
});

enum RfqViewStatus { initial, loading, success, failure }

/// Generic state container for an RFQ-module resource, mirroring the orders /
/// reviews module style.
class RfqDataState<T> {
  const RfqDataState({
    this.status = RfqViewStatus.initial,
    this.data,
    this.message,
  });

  final RfqViewStatus status;
  final T? data;
  final String? message;

  bool get isLoading => status == RfqViewStatus.loading;

  RfqDataState<T> copyWith({
    RfqViewStatus? status,
    T? data,
    String? message,
    bool clearMessage = false,
  }) {
    return RfqDataState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// Shared run helper that maps actions into loading/success/failure states.
class _Runner<T> {
  _Runner(this._read, this._write);

  final RfqDataState<T> Function() _read;
  final void Function(RfqDataState<T>) _write;

  Future<void> run(Future<T> Function() action) async {
    _write(_read().copyWith(status: RfqViewStatus.loading, clearMessage: true));
    try {
      final data = await action();
      _write(RfqDataState<T>(status: RfqViewStatus.success, data: data));
    } catch (error) {
      _write(
        _read().copyWith(
          status: RfqViewStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }
}

// My RFQs list ----------------------------------------------------------------

final myRfqsProvider =
    StateNotifierProvider<MyRfqsNotifier, RfqDataState<List<Rfq>>>((ref) {
      return MyRfqsNotifier(ref.watch(rfqRepositoryProvider));
    });

class MyRfqsNotifier extends StateNotifier<RfqDataState<List<Rfq>>> {
  MyRfqsNotifier(this._repository) : super(const RfqDataState<List<Rfq>>()) {
    _runner = _Runner<List<Rfq>>(() => state, (v) => state = v);
  }

  final RFQRepository _repository;
  late final _Runner<List<Rfq>> _runner;

  Future<void> load() => _runner.run(() => _repository.getMyRfqs());

  /// Creates an RFQ then refreshes the list. Returns null on success or a
  /// user-facing error message on failure (list left intact).
  Future<String?> create({
    required int quantity,
    String? productId,
    String? productVariantId,
    String? sellerProfileId,
    String? businessProfileId,
    double? targetPrice,
    String currency = 'PKR',
    String? message,
  }) async {
    try {
      await _repository.createRfq(
        quantity: quantity,
        productId: productId,
        productVariantId: productVariantId,
        sellerProfileId: sellerProfileId,
        businessProfileId: businessProfileId,
        targetPrice: targetPrice,
        currency: currency,
        message: message,
      );
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}

// RFQ detail ------------------------------------------------------------------

final rfqDetailProvider =
    StateNotifierProvider.family<
      RfqDetailNotifier,
      RfqDataState<RfqDetail>,
      String
    >((ref, rfqId) {
      return RfqDetailNotifier(ref.watch(rfqRepositoryProvider), rfqId);
    });

class RfqDetailNotifier extends StateNotifier<RfqDataState<RfqDetail>> {
  RfqDetailNotifier(this._repository, this._rfqId)
    : super(const RfqDataState<RfqDetail>()) {
    _runner = _Runner<RfqDetail>(() => state, (v) => state = v);
  }

  final RFQRepository _repository;
  final String _rfqId;
  late final _Runner<RfqDetail> _runner;

  Future<void> load() => _runner.run(() => _repository.getRfq(_rfqId));

  /// Cancels the RFQ then reloads it. Returns true on success.
  Future<bool> cancel() async {
    var succeeded = false;
    await _runner.run(() async {
      await _repository.cancelRfq(_rfqId);
      succeeded = true;
      return await _repository.getRfq(_rfqId);
    });
    return succeeded && state.status == RfqViewStatus.success;
  }

  /// Accepts [quoteId] and creates an order shipping to [addressId], then
  /// reloads the RFQ. Returns the new order id on success, or null on failure
  /// (the failure message is set on state for the caller to surface).
  Future<String?> accept({
    required String quoteId,
    required String addressId,
  }) async {
    final previous = state;
    state = state.copyWith(status: RfqViewStatus.loading, clearMessage: true);
    final String orderId;
    try {
      orderId = await _repository.acceptQuote(
        quoteId: quoteId,
        addressId: addressId,
      );
    } catch (error) {
      state = previous.copyWith(
        status: RfqViewStatus.failure,
        message: error.toString(),
      );
      return null;
    }
    await load();
    return orderId;
  }
}
