import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so
/// the profile module never surfaces raw Supabase errors to the UI.
class ProfileFailureMapper {
  const ProfileFailureMapper._();

  static Failure map(Object error) {
    // Already a domain failure (e.g. validation) – pass through unchanged.
    if (error is Failure) {
      return error;
    }

    if (error is ex.NetworkException) {
      return Failure(
        message: 'Network error. Check your connection and try again.',
        code: error.code,
      );
    }
    if (error is ex.StorageException) {
      return Failure(
        message: 'Could not process the image. Please try again.',
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
      return _database(error);
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Something went wrong. Please try again.',
        code: error.code,
      );
    }

    return _fallback(error);
  }

  static Failure _database(ex.DatabaseException error) {
    switch (error.code) {
      case '23505':
        return Failure(
          message: 'This record already exists.',
          code: error.code,
        );
      case '23503':
        return Failure(
          message: 'A related record was not found.',
          code: error.code,
        );
      case '23502':
        return Failure(
          message: 'Required information is missing.',
          code: error.code,
        );
      case '23514':
        return Failure(
          message: 'Some of the provided values are invalid.',
          code: error.code,
        );
      case 'PGRST116':
        return Failure(
          message: 'The requested record was not found.',
          code: error.code,
        );
    }

    final lower = error.message.toLowerCase();
    if (lower.contains('row-level security') || lower.contains('permission')) {
      return Failure(
        message: 'You are not allowed to perform this action.',
        code: error.code,
      );
    }
    return Failure(
      message: 'Something went wrong. Please try again.',
      code: error.code,
    );
  }

  static Failure _fallback(Object error) {
    final typeName = error.runtimeType.toString().toLowerCase();
    final text = error.toString().toLowerCase();
    if (typeName.contains('socket') ||
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
