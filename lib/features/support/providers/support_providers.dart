import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_support_repository.dart';
import '../domain/entities/support_ticket.dart';
import '../domain/repositories/support_repository.dart';

/// Repository binding (lazy service — stays test-safe without an initialized
/// Supabase client).
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupabaseSupportRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

enum SupportStatus { initial, loading, success, failure }

class SupportState {
  const SupportState({
    this.status = SupportStatus.initial,
    this.tickets = const [],
    this.message,
  });

  final SupportStatus status;
  final List<SupportTicket> tickets;
  final String? message;

  SupportState copyWith({
    SupportStatus? status,
    List<SupportTicket>? tickets,
    String? message,
    bool clearMessage = false,
  }) {
    return SupportState(
      status: status ?? this.status,
      tickets: tickets ?? this.tickets,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// Tickets visible to the caller — own for users, all for admins (RLS-scoped).
final ticketsProvider =
    StateNotifierProvider<TicketsNotifier, SupportState>((ref) {
      return TicketsNotifier(ref.watch(supportRepositoryProvider));
    });

class TicketsNotifier extends StateNotifier<SupportState> {
  TicketsNotifier(this._repository) : super(const SupportState());

  final SupportRepository _repository;
  String? _statusFilter;

  String? get statusFilter => _statusFilter;

  Future<void> load({String? status, bool setFilter = false}) async {
    if (setFilter) _statusFilter = status;
    state = state.copyWith(status: SupportStatus.loading, clearMessage: true);
    try {
      state = SupportState(
        status: SupportStatus.success,
        tickets: await _repository.list(status: _statusFilter),
      );
    } catch (error) {
      state = state.copyWith(
        status: SupportStatus.failure,
        message: error.toString(),
      );
    }
  }

  /// Creates a ticket then reloads. Returns null on success or an error message.
  Future<String?> create({
    required String subject,
    required String description,
    required String category,
    String priority = 'normal',
    String? orderId,
  }) => _run(
    () => _repository.create(
      subject: subject,
      description: description,
      category: category,
      priority: priority,
      orderId: orderId,
    ),
  );

  Future<String?> assignToMe(String id) =>
      _run(() => _repository.assignToMe(id));

  Future<String?> setStatus(String id, String status) =>
      _run(() => _repository.setStatus(id: id, status: status));

  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
