import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so the
/// admin feature never surfaces raw Supabase errors to the UI.
class AdminFailureMapper {
  const AdminFailureMapper._();

  static Failure map(Object error) {
    if (error is Failure) return error;
    if (error is ex.NetworkException) {
      return Failure(
        message: 'Network error. Check your connection and try again.',
        code: error.code,
      );
    }
    if (error is ex.AuthException) {
      return Failure(message: 'Please sign in.', code: error.code);
    }
    if (error is ex.DatabaseException) {
      final lower = error.message.toLowerCase();
      if (error.code == '42501' ||
          lower.contains('row-level security') ||
          lower.contains('administrator') ||
          lower.contains('permission')) {
        return Failure(
          message: 'You do not have permission to perform this action.',
          code: error.code,
        );
      }
      if (error.code == '23505') {
        return Failure(
          message: 'That already exists — the name or slug must be unique.',
          code: error.code,
        );
      }
      if (error.code == '23514') {
        return Failure(
          message: 'Some fields are invalid. Check the slug format and '
              'required values.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not complete the action. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not complete the action. Please try again.',
        code: error.code,
      );
    }
    return const Failure(message: 'Something went wrong. Please try again.');
  }
}
