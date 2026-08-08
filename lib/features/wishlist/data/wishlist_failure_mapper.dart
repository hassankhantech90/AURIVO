import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so
/// the wishlist feature never surfaces raw Supabase errors to the UI.
class WishlistFailureMapper {
  const WishlistFailureMapper._();

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
        message: 'Please sign in to use your wishlist.',
        code: error.code,
      );
    }
    if (error is ex.DatabaseException) {
      switch (error.code) {
        case '23505':
          return Failure(
            message: 'This product is already in your wishlist.',
            code: error.code,
          );
        case '23503':
          return Failure(
            message: 'That product is no longer available.',
            code: error.code,
          );
      }
      final lower = error.message.toLowerCase();
      if (lower.contains('row-level security') ||
          lower.contains('permission')) {
        return Failure(
          message: 'Please sign in to use your wishlist.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not update your wishlist. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not update your wishlist. Please try again.',
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
