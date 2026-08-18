import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_repository.dart';
import '../support_failure_mapper.dart';

/// Supabase-backed [SupportRepository]. Relies on the existing support_tickets
/// RLS (owner/assignee/admin); it never bypasses security and resolves the
/// owner server-side via `current_profile_id`. Soft-deleted rows are filtered
/// client-side.
class SupabaseSupportRepository implements SupportRepository {
  SupabaseSupportRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _table = 'support_tickets';

  @override
  Future<SupportTicket> create({
    required String subject,
    required String description,
    String category = 'general',
    String priority = 'normal',
    String? orderId,
  }) async {
    try {
      final row = await _database.insert(
        table: _table,
        values: {
          'profile_id': await _requireProfileId(),
          'subject': subject.trim(),
          'description': description.trim(),
          'category': category,
          'priority': priority,
          'order_id': ?orderId,
        },
      );
      return SupportTicket.fromMap(row);
    } catch (error) {
      throw SupportFailureMapper.map(error);
    }
  }

  @override
  Future<List<SupportTicket>> list({String? status}) async {
    try {
      final rows = await _database.list(
        table: _table,
        filters: {'status': ?status},
        orderBy: 'created_at',
        ascending: false,
        limit: 200,
      );
      return rows
          .where((r) => r['deleted_at'] == null)
          .map(SupportTicket.fromMap)
          .toList();
    } catch (error) {
      throw SupportFailureMapper.map(error);
    }
  }

  @override
  Future<void> assignToMe(String id) async {
    try {
      await _database.update(
        table: _table,
        values: {'assigned_to': await _requireProfileId()},
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw SupportFailureMapper.map(error);
    }
  }

  @override
  Future<void> setStatus({required String id, required String status}) async {
    try {
      await _database.update(
        table: _table,
        values: {
          'status': status,
          'closed_at': status == 'closed'
              ? DateTime.now().toUtc().toIso8601String()
              : null,
        },
        matchColumn: 'id',
        matchValue: id,
      );
    } catch (error) {
      throw SupportFailureMapper.map(error);
    }
  }

  Future<String> _requireProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) return result;
    throw const Failure(message: 'Please sign in to contact support.');
  }
}
