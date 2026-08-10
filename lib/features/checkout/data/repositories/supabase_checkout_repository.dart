import '../../../../core/supabase/supabase_auth_service.dart';
import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../../orders/domain/entities/order_status.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../checkout_failure_mapper.dart';

/// Supabase-backed [CheckoutRepository].
///
/// Delegates entirely to the `checkout_cart` SECURITY DEFINER RPC, which:
/// - validates cart ownership + active state and address ownership,
/// - computes the subtotal/grand total server-side from each line's
///   `unit_price_snapshot` (the client never sends money),
/// - validates stock and reserves inventory per line,
/// - creates the order, order items, the (COD/manual, pending) payment row, and
///   the initial status-history entry, then marks the cart converted.
///
/// This class deliberately duplicates none of that business logic.
class SupabaseCheckoutRepository implements CheckoutRepository {
  SupabaseCheckoutRepository({
    required SupabaseDatabaseService database,
    required SupabaseAuthService authService,
  }) : _database = database,
       _authService = authService;

  final SupabaseDatabaseService _database;
  final SupabaseAuthService _authService;

  @override
  bool get isAuthenticated => _authService.currentUser != null;

  @override
  Future<String> placeOrder({
    required String cartId,
    required String addressId,
    String paymentMethod = PaymentMethod.cashOnDelivery,
    String? notes,
  }) async {
    try {
      final result = await _database.rpc(
        functionName: 'checkout_cart',
        params: {
          'p_cart_id': cartId,
          'p_address_id': addressId,
          'p_payment_method': paymentMethod,
          if (notes != null && notes.trim().isNotEmpty) 'p_notes': notes.trim(),
        },
      );
      final orderId = _asOrderId(result);
      if (orderId == null || orderId.isEmpty) {
        throw const Failure(
          message: 'Your order could not be confirmed. Please try again.',
        );
      }
      return orderId;
    } catch (error) {
      throw CheckoutFailureMapper.map(error);
    }
  }

  /// `checkout_cart` returns a scalar `uuid`. PostgREST may surface it as a bare
  /// String, or (defensively) wrapped in a single-row/single-value shape.
  String? _asOrderId(Object? result) {
    if (result is String) return result;
    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is String) return first;
      if (first is Map && first.isNotEmpty) {
        return first.values.first?.toString();
      }
    }
    if (result is Map && result.isNotEmpty) {
      return result.values.first?.toString();
    }
    return null;
  }
}
