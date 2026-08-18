import '../entities/support_ticket.dart';

/// Contract for support tickets. RLS scopes reads/writes: a user sees & manages
/// their own tickets; an admin (or assignee) sees & manages all. `profile_id` is
/// resolved server-side — never taken from the UI. Failures map to `Failure`.
abstract class SupportRepository {
  /// Creates a ticket owned by the current user.
  Future<SupportTicket> create({
    required String subject,
    required String description,
    String category,
    String priority,
    String? orderId,
  });

  /// Tickets visible to the caller (own for users; all for admins), newest
  /// first, optionally filtered by [status].
  Future<List<SupportTicket>> list({String? status});

  /// Assigns the ticket to the current user (admin/support use).
  Future<void> assignToMe(String id);

  /// Updates a ticket's status (sets `closed_at` when moving to `closed`).
  Future<void> setStatus({required String id, required String status});
}
