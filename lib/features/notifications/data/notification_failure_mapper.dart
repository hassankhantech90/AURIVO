import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so the
/// notifications feature never surfaces raw Supabase errors to the UI.
class NotificationFailureMapper {
  const NotificationFailureMapper._();

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
        message: 'Please sign in to see your notifications.',
        code: error.code,
      );
    }
    if (error is ex.DatabaseException) {
      final lower = error.message.toLowerCase();
      if (lower.contains('row-level security') ||
          lower.contains('permission')) {
        return Failure(
          message: 'Please sign in to see your notifications.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not load your notifications. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not load your notifications. Please try again.',
        code: error.code,
      );
    }
    return const Failure(message: 'Something went wrong. Please try again.');
  }
}
