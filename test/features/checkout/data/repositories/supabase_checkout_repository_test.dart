import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/checkout/data/repositories/supabase_checkout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class _StubAuth extends SupabaseAuthService {
  _StubAuth(this._user) : super(supabaseService: const SupabaseService());
  final supabase.User? _user;
  @override
  supabase.User? get currentUser => _user;
}

supabase.User _user() => supabase.User(
  id: 'auth-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? throwError;
  Object? rpcResult = 'order-1';
  final List<Map<String, dynamic>> rpcCalls = [];

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    if (throwError != null) throw throwError!;
    rpcCalls.add({'fn': functionName, ...params});
    return rpcResult;
  }
}

void main() {
  late _StubDatabase db;

  SupabaseCheckoutRepository build({bool authenticated = true}) {
    return SupabaseCheckoutRepository(
      database: db,
      authService: _StubAuth(authenticated ? _user() : null),
    );
  }

  setUp(() => db = _StubDatabase());

  test('isAuthenticated reflects the auth session', () {
    expect(build(authenticated: true).isAuthenticated, isTrue);
    expect(build(authenticated: false).isAuthenticated, isFalse);
  });

  test('placeOrder calls checkout_cart with only the allowed params', () async {
    final repo = build();

    final orderId = await repo.placeOrder(
      cartId: 'cart-1',
      addressId: 'addr-1',
      notes: 'ring the bell',
    );

    expect(orderId, 'order-1');
    final call = db.rpcCalls.single;
    expect(call['fn'], 'checkout_cart');
    expect(call['p_cart_id'], 'cart-1');
    expect(call['p_address_id'], 'addr-1');
    expect(call['p_payment_method'], 'cash_on_delivery');
    expect(call['p_notes'], 'ring the bell');

    // Critically: the client never sends prices/totals — the RPC is authoritative.
    for (final forbidden in const [
      'p_subtotal',
      'p_grand_total',
      'p_total',
      'p_shipping_fee',
      'p_tax_total',
      'p_discount_total',
      'p_price',
      'p_amount',
    ]) {
      expect(call.containsKey(forbidden), isFalse, reason: forbidden);
    }
  });

  test('placeOrder omits notes when blank', () async {
    final repo = build();
    await repo.placeOrder(cartId: 'c', addressId: 'a', notes: '   ');
    expect(db.rpcCalls.single.containsKey('p_notes'), isFalse);
  });

  test('surfaces a raised RPC message (P0001) as a Failure', () async {
    db.throwError = const ex.DatabaseException('Cart is empty.', code: 'P0001');
    final repo = build();

    await expectLater(
      repo.placeOrder(cartId: 'c', addressId: 'a'),
      throwsA(predicate((e) => e is Failure && e.message == 'Cart is empty.')),
    );
  });

  test('throws a Failure when the RPC returns no order id', () async {
    db.rpcResult = null;
    final repo = build();

    await expectLater(
      repo.placeOrder(cartId: 'c', addressId: 'a'),
      throwsA(isA<Failure>()),
    );
  });

  test('never surfaces a raw Supabase exception', () async {
    db.throwError = const ex.NetworkException('offline');
    final repo = build();
    await expectLater(
      repo.placeOrder(cartId: 'c', addressId: 'a'),
      throwsA(predicate((e) => e is Failure && e is! ex.AppSupabaseException)),
    );
  });
}
