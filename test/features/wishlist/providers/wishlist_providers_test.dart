import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/products/domain/repositories/product_repository.dart';
import 'package:aurivo/features/products/providers/product_providers.dart';
import 'package:aurivo/features/wishlist/domain/entities/wishlist_item.dart';
import 'package:aurivo/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:aurivo/features/wishlist/providers/wishlist_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWishlistRepository implements WishlistRepository {
  _FakeWishlistRepository({Set<String>? ids, this.error})
    : _ids = ids ?? <String>{};

  final Set<String> _ids;
  final Object? error;

  @override
  Future<Set<String>> getWishlistedProductIds() async {
    if (error != null) throw error!;
    return {..._ids};
  }

  @override
  Future<List<WishlistItem>> getWishlist() async {
    if (error != null) throw error!;
    return _ids
        .map((id) => WishlistItem(id: id, profileId: 'p', productId: id))
        .toList();
  }

  @override
  Future<bool> isWishlisted(String productId) async => _ids.contains(productId);

  @override
  Future<WishlistItem> add(String productId) async {
    if (error != null) throw error!;
    _ids.add(productId);
    return WishlistItem(id: productId, profileId: 'p', productId: productId);
  }

  @override
  Future<void> remove(String productId) async {
    if (error != null) throw error!;
    _ids.remove(productId);
  }
}

Product _product(String id) => Product.fromMap({
  'id': id,
  'seller_id': 'seller-1',
  'title': 'Gold Ring $id',
  'slug': 'gold-ring-$id',
  'jewellery_type': 'ring',
  'currency': 'PKR',
  'base_price': 15000,
  'featured': false,
  'rating_average': 0,
  'rating_count': 0,
});

/// ProductRepository fake that only answers getProductsByIds.
class _FakeProductRepository implements ProductRepository {
  List<String> lastRequestedIds = const [];

  @override
  Future<List<Product>> getProductsByIds(List<String> ids) async {
    lastRequestedIds = ids;
    return ids.map(_product).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(WishlistRepository repo) {
  final container = ProviderContainer(
    overrides: [wishlistRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderContainer _containerWithProducts(
  WishlistRepository repo,
  ProductRepository products,
) {
  final container = ProviderContainer(
    overrides: [
      wishlistRepositoryProvider.overrideWithValue(repo),
      productRepositoryProvider.overrideWithValue(products),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts in initial state', () {
    final container = _container(_FakeWishlistRepository());
    expect(container.read(wishlistProvider).status, WishlistStatus.initial);
  });

  test('load populates the wishlisted product ids', () async {
    final container = _container(_FakeWishlistRepository(ids: {'a', 'b'}));

    await container.read(wishlistProvider.notifier).load();

    final state = container.read(wishlistProvider);
    expect(state.status, WishlistStatus.success);
    expect(state.productIds, {'a', 'b'});
    expect(state.contains('a'), isTrue);
  });

  test('toggle adds then removes a product', () async {
    final container = _container(_FakeWishlistRepository());
    final notifier = container.read(wishlistProvider.notifier);

    await notifier.toggle('x');
    expect(container.read(wishlistProvider).productIds, contains('x'));

    await notifier.toggle('x');
    expect(container.read(wishlistProvider).productIds, isNot(contains('x')));
  });

  test('maps repository failure to failure state', () async {
    final container = _container(
      _FakeWishlistRepository(error: const Failure(message: 'Please sign in')),
    );

    await container.read(wishlistProvider.notifier).load();

    final state = container.read(wishlistProvider);
    expect(state.status, WishlistStatus.failure);
    expect(state.message, 'Please sign in');
  });

  group('wishlistProductsProvider', () {
    test('returns empty without hitting products when the set is empty', () async {
      final products = _FakeProductRepository();
      final container = _containerWithProducts(
        _FakeWishlistRepository(),
        products,
      );

      final result = await container.read(wishlistProductsProvider.future);

      expect(result, isEmpty);
      expect(products.lastRequestedIds, isEmpty);
    });

    test('hydrates products for the loaded wishlist ids', () async {
      final products = _FakeProductRepository();
      final container = _containerWithProducts(
        _FakeWishlistRepository(ids: {'a', 'b'}),
        products,
      );
      await container.read(wishlistProvider.notifier).load();

      final result = await container.read(wishlistProductsProvider.future);

      expect(result.map((p) => p.id).toSet(), {'a', 'b'});
      expect(products.lastRequestedIds.toSet(), {'a', 'b'});
    });
  });
}
