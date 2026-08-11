import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/utils/failure.dart';

/// Maps Supabase infrastructure exceptions into the shared [Failure] type for
/// seller product management (never surfaces raw Supabase errors).
class SellerProductFailureMapper {
  const SellerProductFailureMapper._();

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
        message: 'Please sign in to manage your products.',
        code: error.code,
      );
    }
    if (error is ex.DatabaseException) {
      if (error.code == 'P0001') {
        return Failure(message: error.message, code: error.code);
      }
      switch (error.code) {
        case '23505':
          // UNIQUE(slug) (or sku/barcode for variants).
          return Failure(
            message: 'That product URL (slug) is already in use. Try another.',
            code: error.code,
          );
        case '23514':
          return Failure(
            message: 'Some values are invalid. Check price, title, and slug.',
            code: error.code,
          );
        case '23503':
          return Failure(
            message: 'The selected brand or category is no longer available.',
            code: error.code,
          );
      }
      final lower = error.message.toLowerCase();
      if (lower.contains('row-level security') ||
          lower.contains('permission')) {
        return Failure(
          message: 'You are not allowed to modify this product.',
          code: error.code,
        );
      }
      return Failure(
        message: 'Could not save the product. Please try again.',
        code: error.code,
      );
    }
    if (error is ex.AppSupabaseException) {
      return Failure(
        message: 'Could not load your products. Please try again.',
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
