import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so the
/// seller-orders feature never surfaces raw Supabase errors to the UI.
class SellerOrderFailureMapper {
  const SellerOrderFailureMapper._();

  static Failure map(Object error) {
    if (error is Failure) return error;
    if (error is ex.NetworkException) {
      return Failure(
        message: 'Network error. Check your connection and try again.',
        code: error.code,
      );
    }
    if (error is ex.AuthException) {
      return Failure(
        message: 'Please sign in to manage your orders.',
        code: error.code,
      );
    }
    if (error is ex.DatabaseException) {
      if (error.code == '23505') {
        return Failure(
          message: 'That tracking number is already in use.',
          code: error.code,
        );
      }
      final lower = error.message.toLowerCase();
      if (lower.contains('row-level security') ||
          lower.contains('permission')) {
        return Failure(
          message: 'You can only manage orders that include your products.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not update the order. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not update the order. Please try again.',
        code: error.code,
      );
    }
    return const Failure(message: 'Something went wrong. Please try again.');
  }
}
