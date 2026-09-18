import 'package:aurivo/core/storage/secure_storage_service.dart';
import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/cart/data/guest_token_service.dart';
import 'package:aurivo/features/cart/data/repositories/supabase_cart_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

Map<String, dynamic> cartRow({
  String? profileId = 'profile-1',
  String id = 'cart-1',
}) => {
  'id': id,
  'profile_id': profileId,
  'status': 'active',
  'currency': 'PKR',
  'subtotal': 1000,
  'discount_total': 0,
  'grand_total': 1000,
};

Map<String, dynamic> cartItemRow({
  String id = 'item-1',
  String variantId = 'var-1',
  int quantity = 1,
  num price = 1000,
}) => {
  'id': id,
  'cart_id': 'cart-1',
  'product_variant_id': variantId,
  'quantity': quantity,
  'unit_price_snapshot': price,
  'currency': 'PKR',
};

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

class _StubStorage extends SecureStorageService {
  final Map<String, String> _data = {
    'guest_cart_token': 'guesttoken0123456789',
  };
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? throwError;
  Object? rpcResult = 'profile-1'; // current_profile_id default
  List<Map<String, dynamic>> Function(
    String table,
    Map<String, Object?> filters,
  )?
  onList;
  Object? Function(String fn, Map<String, dynamic> params)? onRpc;

  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<Map<String, dynamic>> deleted = [];
  final List<Map<String, dynamic>> rpcCalls = [];

  @override
  Future<List<Map<String, dynamic>>> list({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
    Map<String, List<Object>> whereIn = const {},
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    if (throwError != null) throw throwError!;
    return onList?.call(table, filters) ?? const [];
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (throwError != null) throw throwError!;
    inserted.add({'table': table, ...values});
    if (table == 'carts') return cartRow();
    return {'id': 'item-new', 'currency': 'PKR', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    if (throwError != null) throw throwError!;
    updated.add({'table': table, matchColumn: matchValue, ...values});
    return {'id': matchValue, ...values};
  }

  @override
  Future<void> delete({
    required String table,
    required String matchColumn,
    required Object matchValue,
  }) async {
    if (throwError != null) throw throwError!;
    deleted.add({'table': table, matchColumn: matchValue});
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    if (throwError != null) throw throwError!;
    rpcCalls.add({'fn': functionName, ...params});
    if (onRpc != null) return onRpc!.call(functionName, params);
    if (functionName == 'current_profile_id') return rpcResult;
    return null;
  }
}

void main() {
  late _StubDatabase db;

  SupabaseCartRepository build({required bool authenticated}) {
    return SupabaseCartRepository(
      database: db,
      authService: _StubAuth(authenticated ? _user() : null),
      guestTokenService: GuestTokenService(storage: _StubStorage()),
    );
  }

  setUp(() => db = _StubDatabase());

  group('authenticated cart', () {
    test('getCart creates the active cart when none exists', () async {
      db.onList = (table, filters) => const []; // no cart, no items
      final repo = build(authenticated: true);

      final view = await repo.getCart();

      expect(db.inserted.any((i) => i['table'] == 'carts'), isTrue);
      expect(view.isGuest, isFalse);
      expect(view.isEmpty, isTrue);
    });

    test('addItem inserts a line priced from the live variant', () async {
      db.onList = (table, filters) {
        switch (table) {
          case 'carts':
            return [cartRow()];
          case 'cart_items':
            // first call (find) empty; reload returns the new item
            return db.inserted.any((i) => i['table'] == 'cart_items')
                ? [cartItemRow()]
                : const [];
          case 'product_variants':
            return [
              {'id': 'var-1', 'price': 1500, 'currency': 'PKR'},
            ];
          default:
            return const [];
        }
      };
      final repo = build(authenticated: true);

      final view = await repo.addItem(productVariantId: 'var-1', quantity: 2);

      final insertedItem = db.inserted.firstWhere(
        (i) => i['table'] == 'cart_items',
      );
      expect(insertedItem['unit_price_snapshot'], 1500);
      expect(insertedItem['quantity'], 2);
      expect(view.itemCount, 1);
    });

    test('addItem increments an existing line', () async {
      db.onList = (table, filters) {
        if (table == 'carts') return [cartRow()];
        if (table == 'cart_items') return [cartItemRow(quantity: 1)];
        return const [];
      };
      final repo = build(authenticated: true);

      await repo.addItem(productVariantId: 'var-1', quantity: 2);

      expect(db.updated.single['quantity'], 3); // 1 + 2
    });

    test('updateQuantity to 0 deletes the line', () async {
      db.onList = (table, filters) {
        if (table == 'carts') return [cartRow()];
        if (table == 'cart_items') return [cartItemRow()];
        return const [];
      };
      final repo = build(authenticated: true);

      await repo.updateQuantity(productVariantId: 'var-1', quantity: 0);

      expect(db.deleted.any((d) => d['table'] == 'cart_items'), isTrue);
    });

    test('clearCart deletes all items by cart id', () async {
      db.onList = (table, filters) => table == 'carts' ? [cartRow()] : const [];
      final repo = build(authenticated: true);

      await repo.clearCart();

      final del = db.deleted.firstWhere((d) => d['table'] == 'cart_items');
      expect(del['cart_id'], 'cart-1');
    });

    test('addItem fails when the variant is unavailable', () async {
      db.onList = (table, filters) => table == 'carts' ? [cartRow()] : const [];
      final repo = build(authenticated: true);

      await expectLater(
        repo.addItem(productVariantId: 'missing'),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('guest cart', () {
    test('getCart uses the guest RPCs and marks the cart as guest', () async {
      db.onRpc = (fn, params) {
        if (fn == 'guest_cart_get_or_create') return cartRow(profileId: null);
        if (fn == 'guest_cart_items') return <Map<String, dynamic>>[];
        return null;
      };
      final repo = build(authenticated: false);

      final view = await repo.getCart();

      expect(view.isGuest, isTrue);
      expect(
        db.rpcCalls.any((c) => c['fn'] == 'guest_cart_get_or_create'),
        isTrue,
      );
      expect(db.rpcCalls.every((c) => c['fn'] != 'current_profile_id'), isTrue);
    });

    test('addItem increments via set_item using the token', () async {
      db.onRpc = (fn, params) {
        if (fn == 'guest_cart_get_or_create') return cartRow(profileId: null);
        if (fn == 'guest_cart_items') {
          return [cartItemRow(quantity: 1)];
        }
        return cartItemRow(quantity: 3);
      };
      final repo = build(authenticated: false);

      await repo.addItem(productVariantId: 'var-1', quantity: 2);

      final setCall = db.rpcCalls.firstWhere(
        (c) => c['fn'] == 'guest_cart_set_item',
      );
      expect(setCall['p_guest_token'], 'guesttoken0123456789');
      expect(setCall['p_product_variant_id'], 'var-1');
      expect(setCall['p_quantity'], 3); // 1 + 2
    });

    test('removeItem calls set_item with quantity 0', () async {
      db.onRpc = (fn, params) {
        if (fn == 'guest_cart_get_or_create') return cartRow(profileId: null);
        if (fn == 'guest_cart_items') return <Map<String, dynamic>>[];
        return null;
      };
      final repo = build(authenticated: false);

      await repo.removeItem(productVariantId: 'var-1');

      final setCall = db.rpcCalls.firstWhere(
        (c) => c['fn'] == 'guest_cart_set_item',
      );
      expect(setCall['p_quantity'], 0);
    });

    test('surfaces a raised RPC message (P0001) as a Failure', () async {
      db.throwError = const ex.DatabaseException(
        'Product variant is not available.',
        code: 'P0001',
      );
      final repo = build(authenticated: false);

      await expectLater(
        repo.getCart(),
        throwsA(
          predicate(
            (e) =>
                e is Failure &&
                e.message == 'Product variant is not available.',
          ),
        ),
      );
    });
  });

  group('product-title enrichment', () {
    test('authenticated cart maps the product title', () async {
      db.onList = (table, filters) {
        switch (table) {
          case 'carts':
            return [cartRow()];
          case 'cart_items':
            return [cartItemRow(variantId: 'var-1')];
          case 'product_variants':
            return [
              {'id': 'var-1', 'product_id': 'prod-1'},
            ];
          case 'products':
            return [
              {'id': 'prod-1', 'title': '[TEST] Gold Diamond Solitaire Ring'},
            ];
          default:
            return const [];
        }
      };
      final repo = build(authenticated: true);

      final view = await repo.getCart();

      expect(
        view.items.single.productTitle,
        '[TEST] Gold Diamond Solitaire Ring',
      );
    });

    test('guest cart maps the product title via public catalogue reads', () async {
      db.onRpc = (fn, params) {
        if (fn == 'guest_cart_get_or_create') return cartRow(profileId: null);
        if (fn == 'guest_cart_items') return [cartItemRow(variantId: 'var-1')];
        return null;
      };
      db.onList = (table, filters) {
        if (table == 'product_variants') {
          return [
            {'id': 'var-1', 'product_id': 'prod-1'},
          ];
        }
        if (table == 'products') {
          return [
            {'id': 'prod-1', 'title': '[TEST] Emerald Jhumka Earrings'},
          ];
        }
        return const [];
      };
      final repo = build(authenticated: false);

      final view = await repo.getCart();

      expect(
        view.items.single.productTitle,
        '[TEST] Emerald Jhumka Earrings',
      );
    });

    test('unresolved product keeps the title null without crashing', () async {
      db.onList = (table, filters) {
        switch (table) {
          case 'carts':
            return [cartRow()];
          case 'cart_items':
            return [cartItemRow(variantId: 'var-1')];
          default:
            return const []; // variant/product not publicly visible
        }
      };
      final repo = build(authenticated: true);

      final view = await repo.getCart();

      expect(view.items.single.productTitle, isNull);
    });
  });

  test('never surfaces a raw Supabase exception', () async {
    db.throwError = const ex.NetworkException('offline');
    final repo = build(authenticated: true);
    await expectLater(
      repo.getCart(),
      throwsA(predicate((e) => e is Failure && e is! ex.AppSupabaseException)),
    );
  });
}
