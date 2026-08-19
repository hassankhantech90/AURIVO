import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so the
/// chat feature never surfaces raw Supabase errors to the UI.
class ChatFailureMapper {
  const ChatFailureMapper._();

  static Failure map(Object error) {
    if (error is Failure) return error;
    if (error is ex.NetworkException) {
      return Failure(
        message: 'Network error. Check your connection and try again.',
        code: error.code,
      );
    }
    if (error is ex.AuthException) {
      return Failure(message: 'Please sign in to chat.', code: error.code);
    }
    if (error is ex.DatabaseException) {
      final lower = error.message.toLowerCase();
      if (error.code == '42501' ||
          lower.contains('row-level security') ||
          lower.contains('permission') ||
          lower.contains('participant') ||
          lower.contains('authorized')) {
        return Failure(
          message: 'You are not able to access this conversation.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not send. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not complete the request. Please try again.',
        code: error.code,
      );
    }
    return const Failure(message: 'Something went wrong. Please try again.');
  }
}
