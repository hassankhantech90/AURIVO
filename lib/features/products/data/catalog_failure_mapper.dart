import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so
/// the catalogue (products + categories) never surfaces raw Supabase errors.
class CatalogFailureMapper {
  const CatalogFailureMapper._();

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
      if (error.code == 'PGRST116') {
        return Failure(
          message: 'The requested item was not found.',
          code: error.code,
        );
      }
      final lower = error.message.toLowerCase();
      if (lower.contains('row-level security') ||
          lower.contains('permission')) {
        return Failure(
          message: 'This item is not available.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not load the catalogue. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not load the catalogue. Please try again.',
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
