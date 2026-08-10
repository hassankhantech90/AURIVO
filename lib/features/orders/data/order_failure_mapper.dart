import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so
/// the orders feature never surfaces raw Supabase errors to the UI.
class OrderFailureMapper {
  const OrderFailureMapper._();

  static Failure map(Object error) {
    if (error is Failure) {
      return error;
    }
    if (error is ex.NetworkException) {
      return Failure(
        message: 'Network error. Check your connection and try again.',
        code: error.code,
      );
    }
    if (error is ex.AuthException) {
      return Failure(
        message: 'Please sign in to view your orders.',
        code: error.code,
      );
    }
    if (error is ex.DatabaseException) {
      // `cancel_order` raises its own user-facing messages (SQLSTATE P0001),
      // e.g. "Order can no longer be cancelled.",
      // "Order not found for this profile." — surface those directly.
      if (error.code == 'P0001') {
        return Failure(message: error.message, code: error.code);
      }
      final lower = error.message.toLowerCase();
      if (lower.contains('row-level security') ||
          lower.contains('permission')) {
        return Failure(
          message: 'You are not allowed to view this order.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not load your orders. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not load your orders. Please try again.',
        code: error.code,
      );
    }

    final text = error.toString().toLowerCase();
    if (error.runtimeType.toString().toLowerCase().contains('socket') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network')) {
      return const Failure(
        message: 'Network error. Check your connection and try again.',
      );
    }
    return const Failure(message: 'Something went wrong. Please try again.');
  }
}
