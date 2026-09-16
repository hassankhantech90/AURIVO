import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../../products/domain/entities/product.dart';
import '../../products/providers/catalog_state.dart';
import '../../products/providers/product_providers.dart';
import '../../wishlist/presentation/widgets/wishlist_product_card.dart';
import '../../wishlist/providers/wishlist_providers.dart';

/// Explore surface: the full public product catalogue grid, wired to
/// [exploreProductsProvider] — a dedicated state independent of Home's
/// [productListProvider], so the two surfaces never overwrite each other.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    if (ref.read(sessionProvider).isAuthenticated) {
      ref.read(wishlistProvider.notifier).load();
    }
    return ref.read(exploreProductsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreProductsProvider);
    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Explore'),
      body: RefreshIndicator(onRefresh: _load, child: _body(state)),
    );
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
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No products found',
                message: 'The catalogue is empty right now.',
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
