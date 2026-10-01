import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase exceptions into [Failure] for disputes. The dispute RPCs
/// raise user-readable messages (P0001 / 42501), which pass straight through.
class DisputeFailureMapper {
  const DisputeFailureMapper._();

  static Failure map(Object error) {
    if (error is Failure) return error;
    if (error is ex.NetworkException) {
      return Failure(
        message: 'Network error. Check your connection and try again.',
        code: error.code,
      );
    }
    if (error is ex.AuthException) {
      return Failure(message: 'Please sign in to continue.', code: error.code);
    }
    if (error is ex.DatabaseException) {
      if (error.code == 'P0001' || error.code == '42501') {
        return Failure(message: error.message, code: error.code);
      }
      if (error.code == '23505') {
        return Failure(
          message: 'A dispute is already open for this order.',
          code: error.code,
        );
      }
      final lower = error.message.toLowerCase();
      if (lower.contains('row-level security')) {
        return Failure(
          message: 'This dispute is closed or you are not part of it.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not update the dispute. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not load the dispute. Please try again.',
        code: error.code,
      );
    }
    if (error is StateError) return Failure(message: error.message);
    return const Failure(message: 'Something went wrong. Please try again.');
  }
}
