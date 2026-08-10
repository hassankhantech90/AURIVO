import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../orders/domain/entities/order_status.dart';
import '../data/repositories/supabase_checkout_repository.dart';
import '../domain/repositories/checkout_repository.dart';

/// Repository binding for checkout (lazy services — stays test-safe without an
/// initialized Supabase client).
final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  const service = SupabaseService();
  return SupabaseCheckoutRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
    authService: const SupabaseAuthService(supabaseService: service),
  );
});

enum CheckoutStatus { idle, submitting, success, failure }

/// State for a single checkout submission. On success [orderId] carries the id
/// returned by the `checkout_cart` RPC so the UI can navigate to the order.
class CheckoutState {
  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.orderId,
    this.message,
  });

  final CheckoutStatus status;
  final String? orderId;
  final String? message;

  bool get isSubmitting => status == CheckoutStatus.submitting;

  CheckoutState copyWith({
    CheckoutStatus? status,
    String? orderId,
    String? message,
    bool clearMessage = false,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final checkoutProvider = StateNotifierProvider<CheckoutNotifier, CheckoutState>(
  (ref) {
    return CheckoutNotifier(ref.watch(checkoutRepositoryProvider));
  },
);

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier(this._repository) : super(const CheckoutState());

  final CheckoutRepository _repository;

  bool get isAuthenticated => _repository.isAuthenticated;

  /// Submits the cart to the `checkout_cart` RPC. Returns the new order id on
  /// success, or null on failure (with [state] carrying the message).
  Future<String?> placeOrder({
    required String cartId,
    required String addressId,
    String paymentMethod = PaymentMethod.cashOnDelivery,
    String? notes,
  }) async {
    if (state.isSubmitting) return null;
    state = const CheckoutState(status: CheckoutStatus.submitting);
    try {
      final orderId = await _repository.placeOrder(
        cartId: cartId,
        addressId: addressId,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      state = CheckoutState(status: CheckoutStatus.success, orderId: orderId);
      return orderId;
    } catch (error) {
      state = CheckoutState(
        status: CheckoutStatus.failure,
        message: error.toString(),
      );
      return null;
    }
  }

  /// Resets to idle (e.g. when leaving the checkout screen).
  void reset() => state = const CheckoutState();
}
