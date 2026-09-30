import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/catalog_filters.dart';
import '../domain/entities/product.dart';
import 'product_providers.dart';

/// Product ids the buyer opened on this device, most recent first
/// (Requirements Doc §4.1 "recently viewed"). Device-local and best-effort:
/// when SharedPreferences is unavailable the list is session-only.
final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<String>>(
      (ref) => RecentlyViewedNotifier(),
    );

class RecentlyViewedNotifier extends StateNotifier<List<String>> {
  RecentlyViewedNotifier({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance,
      super(const []) {
    _restore();
  }

  static const _key = 'products.recently_viewed';
  static const maxItems = 12;

  final Future<SharedPreferences> Function() _preferences;

  Future<void> _restore() async {
    try {
      final saved = (await _preferences()).getStringList(_key) ?? const [];
      if (!mounted) return;
      // Anything recorded while restoring stays on top.
      state = [
        ...state,
        ...saved.where((id) => !state.contains(id)),
      ].take(maxItems).toList();
    } catch (_) {
      // Storage unavailable — keep the in-memory list.
    }
  }

  /// Moves [productId] to the front (adding it if new), capped at [maxItems].
  Future<void> record(String productId) async {
    state = [
      productId,
      ...state.where((id) => id != productId),
    ].take(maxItems).toList();
    try {
      await (await _preferences()).setStringList(_key, state);
    } catch (_) {
      // Storage unavailable — still recorded for this session.
    }
  }
}

/// Recently viewed products in recency order. Products no longer visible
/// (paused, removed) are simply absent — RLS filters them out.
final recentlyViewedProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
      final ids = ref.watch(recentlyViewedProvider);
      if (ids.isEmpty) return const [];
      final products = await ref
          .watch(productRepositoryProvider)
          .getProducts(
            limit: ids.length,
            filters: CatalogFilters(ids: ids),
          );
      final byId = {for (final p in products) p.id: p};
      return [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
    });
