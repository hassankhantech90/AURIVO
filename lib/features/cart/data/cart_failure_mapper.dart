import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so
/// the cart feature never surfaces raw Supabase errors to the UI.
class CartFailureMapper {
  const CartFailureMapper._();

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
        message: 'Your session has expired. Please sign in again.',
        code: error.code,
      );
    }
    if (error is ex.DatabaseException) {
      // Guest-cart RPCs raise their own user-facing messages (SQLSTATE P0001),
      // e.g. "Product variant is not available." — surface those directly.
      if (error.code == 'P0001') {
        return Failure(message: error.message, code: error.code);
      }
      switch (error.code) {
        case '23503':
          return Failure(
            message: 'That product is no longer available.',
            code: error.code,
          );
        case '23514':
          return Failure(
            message: 'Invalid quantity for this item.',
            code: error.code,
          );
      }
      final lower = error.message.toLowerCase();
      if (lower.contains('row-level security') ||
          lower.contains('permission')) {
        return Failure(
          message: 'You are not allowed to modify this cart.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not update your cart. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not update your cart. Please try again.',
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
