import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type so
/// the seller feature (storefront reads and seller-review writes) never
/// surfaces raw Supabase errors to the UI.
class SellerFailureMapper {
  const SellerFailureMapper._();

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
      if (error.code == 'P0001') {
        return Failure(message: error.message, code: error.code);
      }
      switch (error.code) {
        case '23505':
          return Failure(
            message: 'You have already reviewed this seller.',
            code: error.code,
          );
        case '23514':
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
        message: 'Could not complete that. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not load the store. Please try again.',
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
