import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/supabase_return_repository.dart';
import '../domain/entities/return_request.dart';
import '../domain/repositories/return_repository.dart';

final returnRepositoryProvider = Provider<ReturnRepository>((ref) {
  return const SupabaseReturnRepository(
    database: SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

/// The latest return request for an order (null when none), with the actions
/// buyers, sellers and admins may take. Each action reloads the request and
/// returns null on success or a user-facing message on failure.
final orderReturnProvider = StateNotifierProvider.autoDispose
    .family<OrderReturnNotifier, AsyncValue<ReturnRequest?>, String>(
      (ref, orderId) =>
          OrderReturnNotifier(ref.watch(returnRepositoryProvider), orderId),
    );

class OrderReturnNotifier extends StateNotifier<AsyncValue<ReturnRequest?>> {
  OrderReturnNotifier(this._repository, this._orderId)
    : super(const AsyncValue.loading()) {
    load();
  }

  final ReturnRepository _repository;
  final String _orderId;

  Future<void> load() async {
    state = await AsyncValue.guard(() => _repository.latestForOrder(_orderId));
  }

  Future<String?> request({required String reason, String? details}) => _act(
    () => _repository.request(orderId: _orderId, reason: reason, details: details),
  );

  Future<String?> cancel(String id) => _act(() => _repository.cancel(id));

  Future<String?> decide(String id, {required bool approve, String? note}) =>
      _act(() => _repository.decide(id, approve: approve, note: note));

  Future<String?> markReceived(String id) =>
      _act(() => _repository.markReceived(id));

  Future<String?> markRefunded(String id, {String? note}) =>
      _act(() => _repository.markRefunded(id, note: note));

  Future<String?> _act(Future<ReturnRequest> Function() action) async {
    try {
      final updated = await action();
      if (mounted) state = AsyncValue.data(updated);
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
