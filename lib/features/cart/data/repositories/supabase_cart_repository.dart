import '../../../../core/supabase/supabase_auth_service.dart';
import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../../core/utils/db_parsing.dart';
import '../../../../core/utils/failure.dart';
import '../../domain/entities/cart.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/cart_view.dart';
import '../../domain/repositories/cart_repository.dart';
import '../cart_failure_mapper.dart';
import '../guest_token_service.dart';

/// Supabase-backed [CartRepository].
///
/// - Authenticated: reads/writes the RLS-protected `carts` / `cart_items`
///   tables (rows scoped to `profile_id = current_profile_id()`).
/// - Guest: uses ONLY the token-scoped `guest_cart_*` SECURITY DEFINER RPCs;
///   the guest cart tables are never touched directly (RLS forbids it).
///
/// Totals always come from the database-authoritative `carts` row.
class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository({
    required SupabaseDatabaseService database,
    required SupabaseAuthService authService,
    required GuestTokenService guestTokenService,
  }) : _database = database,
       _authService = authService,
       _guestTokenService = guestTokenService;

  final SupabaseDatabaseService _database;
  final SupabaseAuthService _authService;
  final GuestTokenService _guestTokenService;

  // Per-session caches (the provider clears these on any auth identity change).
  // The profile id is stable for a session; product titles are stable per
  // variant. Caching them removes repeated round-trips on every cart tap.
  String? _profileId;
  final Map<String, String> _titleCache = {};

  static const String _cartsTable = 'carts';
  static const String _cartItemsTable = 'cart_items';
  static const String _variantsTable = 'product_variants';
  static const String _productsTable = 'products';

  @override
  bool get isAuthenticated => _authService.currentUser != null;

  @override
  void clearSessionCache() {
    _profileId = null;
    _titleCache.clear();
  }

  @override
  Future<CartView> getCart() async {
    try {
      return isAuthenticated ? await _loadAuth() : await _loadGuest();
    } catch (error) {
      throw CartFailureMapper.map(error);
    }
  }

  @override
  Future<CartView> addItem({
    required String productVariantId,
    int quantity = 1,
  }) async {
    try {
      if (isAuthenticated) {
        return await _addAuth(productVariantId, quantity);
      }
      return await _addGuest(productVariantId, quantity);
    } catch (error) {
      throw CartFailureMapper.map(error);
    }
  }

  @override
  Future<CartView> updateQuantity({
    required String productVariantId,
    required int quantity,
  }) async {
    try {
      if (isAuthenticated) {
        return await _setQuantityAuth(productVariantId, quantity);
      }
      await _guestSetItem(productVariantId, quantity);
      return await _loadGuest();
    } catch (error) {
      throw CartFailureMapper.map(error);
    }
  }

  @override
  Future<CartView> removeItem({required String productVariantId}) async {
    try {
      if (isAuthenticated) {
        return await _setQuantityAuth(productVariantId, 0);
      }
      await _guestSetItem(productVariantId, 0);
      return await _loadGuest();
    } catch (error) {
      throw CartFailureMapper.map(error);
    }
  }

  @override
  Future<CartView> clearCart() async {
    try {
      if (isAuthenticated) {
        final cart = await _getOrCreateActiveCartRow();
        await _database.delete(
          table: _cartItemsTable,
          matchColumn: 'cart_id',
          matchValue: cart['id'] as String,
        );
        return await _loadAuth();
      }
      final view = await _loadGuest();
      for (final item in view.items) {
        await _guestSetItem(item.productVariantId, 0);
      }
      return await _loadGuest();
    } catch (error) {
      throw CartFailureMapper.map(error);
    }
  }

  // Authenticated path --------------------------------------------------------

  Future<CartView> _loadAuth() async {
    final cartRow = await _getOrCreateActiveCartRow();
    return _buildAuthView(cartRow);
  }

  /// Reload after a mutation that already knows the cart id: re-reads the cart
  /// row by id (for the trigger-updated totals) without re-resolving the profile
  /// and re-finding the active cart. Falls back to a full [_loadAuth] if the row
  /// has vanished (e.g. converted at checkout).
  Future<CartView> _loadAuthCart(String cartId) async {
    final rows = await _database.list(
      table: _cartsTable,
      filters: {'id': cartId},
      limit: 1,
    );
    if (rows.isEmpty) return _loadAuth();
    return _buildAuthView(rows.first);
  }

  Future<CartView> _buildAuthView(Map<String, dynamic> cartRow) async {
    final cart = Cart.fromMap(cartRow);
    final itemRows = await _database.list(
      table: _cartItemsTable,
      filters: {'cart_id': cart.id},
      orderBy: 'created_at',
    );
    return _withTitles(
      CartView(cart: cart, items: itemRows.map(CartItem.fromMap).toList()),
    );
  }

  Future<CartView> _addAuth(String variantId, int quantity) async {
    final cartRow = await _getOrCreateActiveCartRow();
    final cartId = cartRow['id'] as String;
    final existing = await _findAuthItem(cartId, variantId);
    if (existing != null) {
      await _database.update(
        table: _cartItemsTable,
        values: {'quantity': existing.quantity + quantity},
        matchColumn: 'id',
        matchValue: existing.id,
      );
    } else {
      final price = await _variantPrice(variantId);
      await _database.insert(
        table: _cartItemsTable,
        values: {
          'cart_id': cartId,
          'product_variant_id': variantId,
          'quantity': quantity,
          'unit_price_snapshot': price.$1,
          'currency': price.$2,
        },
      );
    }
    return _loadAuthCart(cartId);
  }

  Future<CartView> _setQuantityAuth(String variantId, int quantity) async {
    final cartRow = await _getOrCreateActiveCartRow();
    final cartId = cartRow['id'] as String;
    final existing = await _findAuthItem(cartId, variantId);
    if (quantity <= 0) {
      if (existing != null) {
        await _database.delete(
          table: _cartItemsTable,
          matchColumn: 'id',
          matchValue: existing.id,
        );
      }
      return _loadAuthCart(cartId);
    }
    if (existing != null) {
      await _database.update(
        table: _cartItemsTable,
        values: {'quantity': quantity},
        matchColumn: 'id',
        matchValue: existing.id,
      );
    } else {
      final price = await _variantPrice(variantId);
      await _database.insert(
        table: _cartItemsTable,
        values: {
          'cart_id': cartId,
          'product_variant_id': variantId,
          'quantity': quantity,
          'unit_price_snapshot': price.$1,
          'currency': price.$2,
        },
      );
    }
    return _loadAuthCart(cartId);
  }

  Future<Map<String, dynamic>> _getOrCreateActiveCartRow() async {
    final profileId = await _requireProfileId();
    final rows = await _database.list(
      table: _cartsTable,
      filters: {'profile_id': profileId, 'status': 'active'},
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first;
    try {
      return await _database.insert(
        table: _cartsTable,
        values: {'profile_id': profileId, 'status': 'active'},
      );
    } on ex.AppSupabaseException catch (error) {
      // Concurrent creation hit the one-active-cart-per-profile unique index.
      if (error.code == '23505') {
        final again = await _database.list(
          table: _cartsTable,
          filters: {'profile_id': profileId, 'status': 'active'},
          limit: 1,
        );
        if (again.isNotEmpty) return again.first;
      }
      rethrow;
    }
  }

  Future<CartItem?> _findAuthItem(String cartId, String variantId) async {
    final rows = await _database.list(
      table: _cartItemsTable,
      filters: {'cart_id': cartId, 'product_variant_id': variantId},
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CartItem.fromMap(rows.first);
  }

  /// (price, currency) read from the live variant (RLS: active variant of an
  /// approved product). Used as the authoritative snapshot for auth carts.
  Future<(double, String)> _variantPrice(String variantId) async {
    final rows = await _database.list(
      table: _variantsTable,
      columns: 'id, price, currency',
      filters: {'id': variantId},
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const Failure(message: 'This item is not available.');
    }
    final row = rows.first;
    return (parseDouble(row['price']), row['currency'] as String? ?? 'PKR');
  }

  Future<String> _requireProfileId() async {
    final cached = _profileId;
    if (cached != null) return cached;
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) {
      _profileId = result;
      return result;
    }
    throw const Failure(message: 'Please sign in to use your cart.');
  }

  // Guest path (RPCs only) ----------------------------------------------------

  Future<CartView> _loadGuest() async {
    final token = await _guestTokenService.getOrCreate();
    final cartResult = await _database.rpc(
      functionName: 'guest_cart_get_or_create',
      params: {'p_guest_token': token},
    );
    final cart = Cart.fromMap(_asRow(cartResult));
    final itemsResult = await _database.rpc(
      functionName: 'guest_cart_items',
      params: {'p_guest_token': token},
    );
    final items = _asRows(itemsResult).map(CartItem.fromMap).toList();
    return _withTitles(CartView(cart: cart, items: items));
  }

  Future<CartView> _addGuest(String variantId, int quantity) async {
    final token = await _guestTokenService.getOrCreate();
    final itemsResult = await _database.rpc(
      functionName: 'guest_cart_items',
      params: {'p_guest_token': token},
    );
    var current = 0;
    for (final row in _asRows(itemsResult)) {
      if (row['product_variant_id'] == variantId) {
        current = parseInt(row['quantity']);
        break;
      }
    }
    await _guestSetItem(variantId, current + quantity);
    return _loadGuest();
  }

  Future<void> _guestSetItem(String variantId, int quantity) async {
    final token = await _guestTokenService.getOrCreate();
    await _database.rpc(
      functionName: 'guest_cart_set_item',
      params: {
        'p_guest_token': token,
        'p_product_variant_id': variantId,
        'p_quantity': quantity,
      },
    );
  }

  Map<String, dynamic> _asRow(Object? result) {
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw const Failure(message: 'Could not load your cart. Please try again.');
  }

  List<Map<String, dynamic>> _asRows(Object? result) {
    if (result is List) {
      return result
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    }
    if (result is Map) return [Map<String, dynamic>.from(result)];
    return const [];
  }

  // Product-title enrichment --------------------------------------------------

  /// Attaches each line's product title for display. Resolution uses the public,
  /// RLS-governed catalogue tables (approved products only), so it works for
  /// both authenticated and guest sessions without touching the cart RPCs. A
  /// title that cannot be resolved stays null and the UI falls back gracefully.
  Future<CartView> _withTitles(CartView view) async {
    if (view.items.isEmpty) return view;
    final titles = await _titlesForVariants(
      view.items.map((item) => item.productVariantId).toList(),
    );
    if (titles.isEmpty) return view;
    return CartView(
      cart: view.cart,
      items: view.items
          .map(
            (item) =>
                item.copyWith(productTitle: titles[item.productVariantId]),
          )
          .toList(),
    );
  }

  /// Maps each variant id to its product title with exactly two batch queries
  /// (variant -> product id, then product id -> title) — no per-line lookup.
  Future<Map<String, String>> _titlesForVariants(
    List<String> variantIds,
  ) async {
    final ids = variantIds.toSet();
    if (ids.isEmpty) return const {};

    // Serve already-known titles from the cache; only fetch the misses.
    final result = <String, String>{};
    final missing = <String>[];
    for (final id in ids) {
      final cached = _titleCache[id];
      if (cached != null) {
        result[id] = cached;
      } else {
        missing.add(id);
      }
    }
    if (missing.isEmpty) return result;

    final variantRows = await _database.list(
      table: _variantsTable,
      columns: 'id, product_id',
      whereIn: {'id': List<Object>.from(missing)},
    );
    final productIdByVariant = <String, String>{};
    final productIds = <String>{};
    for (final row in variantRows) {
      final variantId = row['id'] as String?;
      final productId = row['product_id'] as String?;
      if (variantId != null && productId != null) {
        productIdByVariant[variantId] = productId;
        productIds.add(productId);
      }
    }
    if (productIds.isEmpty) return result;

    final productRows = await _database.list(
      table: _productsTable,
      columns: 'id, title',
      whereIn: {'id': List<Object>.from(productIds)},
    );
    final titleByProduct = <String, String>{};
    for (final row in productRows) {
      final productId = row['id'] as String?;
      final title = row['title'] as String?;
      if (productId != null && title != null) titleByProduct[productId] = title;
    }

    productIdByVariant.forEach((variantId, productId) {
      final title = titleByProduct[productId];
      if (title != null) {
        result[variantId] = title;
        _titleCache[variantId] = title; // remember for subsequent taps
      }
    });
    return result;
  }
}
