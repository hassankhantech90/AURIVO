import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so
/// the reviews feature never surfaces raw Supabase errors to the UI.
class ReviewFailureMapper {
  const ReviewFailureMapper._();

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
        message: 'Please sign in to manage your review.',
        code: error.code,
      );
    }
    if (error is ex.DatabaseException) {
      // The review integrity trigger may raise its own messages (SQLSTATE
      // P0001) — surface those directly.
      if (error.code == 'P0001') {
        return Failure(message: error.message, code: error.code);
      }
      switch (error.code) {
        case '23505':
          // UNIQUE(profile_id, product_id) / (profile_id, order_item_id).
          return Failure(
            message: 'You have already reviewed this product.',
            code: error.code,
          );
        case '23514':
          // CHECK (rating BETWEEN 1 AND 5).
          return Failure(
            message: 'Please choose a rating between 1 and 5.',
            code: error.code,
          );
      }
      final lower = error.message.toLowerCase();
      if (lower.contains('row-level security') ||
          lower.contains('permission')) {
        return Failure(
          message: 'You are not allowed to modify this review.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not save your review. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not load reviews. Please try again.',
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
