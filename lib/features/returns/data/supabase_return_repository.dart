import '../../../core/supabase/supabase_database_service.dart';
import '../domain/entities/return_request.dart';
import '../domain/repositories/return_repository.dart';
import 'return_failure_mapper.dart';

/// Supabase-backed [ReturnRepository]: reads `return_requests` under RLS and
/// performs every transition through its SECURITY DEFINER RPC.
class SupabaseReturnRepository implements ReturnRepository {
  const SupabaseReturnRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  @override
  Future<ReturnRequest?> latestForOrder(String orderId) async {
    try {
      final rows = await _database.list(
        table: 'return_requests',
        filters: {'order_id': orderId},
        orderBy: 'created_at',
        ascending: false,
        limit: 1,
      );
      return rows.isEmpty ? null : ReturnRequest.fromMap(rows.first);
    } catch (error) {
      throw ReturnFailureMapper.map(error);
    }
  }

  @override
  Future<ReturnRequest> request({
    required String orderId,
    required String reason,
    String? details,
  }) => _call('request_return', {
    'p_order_id': orderId,
    'p_reason': reason,
    'p_details': details,
  });

  @override
  Future<ReturnRequest> cancel(String returnId) =>
      _call('cancel_return', {'p_return_id': returnId});

  @override
  Future<ReturnRequest> decide(
    String returnId, {
    required bool approve,
    String? note,
  }) => _call('decide_return', {
    'p_return_id': returnId,
    'p_approve': approve,
    'p_note': note,
  });

  @override
  Future<ReturnRequest> markReceived(String returnId) =>
      _call('mark_return_received', {'p_return_id': returnId});

  @override
  Future<ReturnRequest> markRefunded(String returnId, {String? note}) =>
      _call('mark_return_refunded', {'p_return_id': returnId, 'p_note': note});

  Future<ReturnRequest> _call(String fn, Map<String, dynamic> params) async {
    try {
      final result = await _database.rpc(functionName: fn, params: params);
      return ReturnRequest.fromMap(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw ReturnFailureMapper.map(error);
    }
  }
}
