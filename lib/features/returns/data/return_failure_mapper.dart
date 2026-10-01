import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase exceptions into [Failure] for the returns feature. The return
/// RPCs raise buyer/seller-readable messages (P0001 / 42501) which are passed
/// straight through.
class ReturnFailureMapper {
  const ReturnFailureMapper._();

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
        message: 'Please sign in to manage returns.',
        code: error.code,
      );
    }
    if (error is ex.DatabaseException) {
      if (error.code == 'P0001' || error.code == '42501') {
        return Failure(message: error.message, code: error.code);
      }
      if (error.code == '23505') {
        return Failure(
          message: 'A return is already in progress for this order.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not update the return. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not load the return. Please try again.',
        code: error.code,
      );
    }
    return const Failure(message: 'Something went wrong. Please try again.');
  }
}
