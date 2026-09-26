import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../../products/domain/entities/product.dart';
import '../../products/providers/catalog_state.dart';
import '../../wishlist/presentation/widgets/wishlist_product_card.dart';
import '../../wishlist/providers/wishlist_providers.dart';
import '../providers/explore_products_provider.dart';

/// Explore surface: the public product catalogue grid, wired to
/// [exploreProductsProvider] — a dedicated state independent of Home's
/// productListProvider. When given a [categoryId] (a root category) it shows
/// that category's whole visible subtree; otherwise the full newest catalogue.
/// [material] narrows the grid to a single metal (e.g. from a Home metal tab).
/// [search] narrows the grid to a title contains-match (e.g. from the Home
/// search bar).
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key, this.categoryId, this.material, this.search});

  /// Root category to filter by (its subtree), or null for the full catalogue.
  final String? categoryId;

  /// Metal to filter by (e.g. 'Gold', 'Silver'), or null for all metals.
  final String? material;

  /// Free-text query to filter by (product title), or null for no query.
  final String? search;

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  late final TextEditingController _controller;

  /// The live query, seeded from the route's [ExplorePage.search] and then
  /// edited in place via the search field. Composes with the metal/category.
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.search?.trim() ?? '';
    _controller = TextEditingController(text: _query);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() {
    if (ref.read(sessionProvider).isAuthenticated) {
      ref.read(wishlistProvider.notifier).load();
    }
    return ref
        .read(exploreProductsProvider.notifier)
        .load(
          rootCategoryId: widget.categoryId,
          material: widget.material,
          search: _query.isEmpty ? null : _query,
        );
  }

  /// Re-runs the catalogue query for a refined [value]; a no-op when the
  /// trimmed query is unchanged, so resubmitting the same text is free.
  void _runSearch(String value) {
    final next = value.trim();
    if (next == _query) return;
    setState(() => _query = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreProductsProvider);
    return Scaffold(
      // A metal filter names the surface; otherwise "Explore". The live query
      // lives in the search field below, not the title.
      appBar: LuxuryAppBar(title: widget.material ?? 'Explore'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => CustomSearchBar(
                controller: _controller,
                hintText: 'Search jewellery',
                onSubmitted: _runSearch,
                onClear: value.text.isEmpty
                    ? null
                    : () {
                        _controller.clear();
                        _runSearch('');
                      },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _body(state)),
          ),
        ],
      ),
    );
  }

  String get _emptyMessage {
    if (_query.isNotEmpty) {
      return 'Nothing matched “$_query”. Try a different search.';
    }
    if (widget.material != null) {
      return 'No ${widget.material!.toLowerCase()} pieces yet — '
          'check back soon.';
    }
    return 'The catalogue is empty right now.';
  }

  Widget _body(CatalogState<List<Product>> state) {
    switch (state.status) {
      case CatalogViewStatus.initial:
      case CatalogViewStatus.loading:
        return const Center(child: LoadingIndicator());
      case CatalogViewStatus.failure:
        return ErrorStateWidget(
          message: state.message ?? 'Could not load the catalogue.',
          onRetry: _load,
        );
      case CatalogViewStatus.success:
        final products = state.data ?? const [];
        if (products.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No products found',
                message: _emptyMessage,
              ),
            ],
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.62,
          ),
          itemBuilder: (context, index) =>
              WishlistProductCard(product: products[index]),
        );
    }
  }
}
