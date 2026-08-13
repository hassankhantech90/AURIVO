import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../providers/wishlist_providers.dart';
import 'widgets/wishlist_product_card.dart';

/// The buyer's saved products. Reads [wishlistProvider] for the id set and
/// [wishlistProductsProvider] for the hydrated products.
class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sessionProvider).isAuthenticated) {
        ref.read(wishlistProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(
      sessionProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated) {
      return Scaffold(
        appBar: const LuxuryAppBar(title: 'Wishlist', showBackButton: true),
        body: EmptyStateWidget(
          title: 'Sign in to view your wishlist',
          message: 'Save products you love and find them here.',
          icon: Icons.favorite_border,
          action: PrimaryButton(
            label: 'Sign in',
            onPressed: () => context.push(AppRoutes.login),
          ),
        ),
      );
    }

    final wishlist = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Wishlist', showBackButton: true),
      body: switch (wishlist.status) {
        WishlistStatus.initial ||
        WishlistStatus.loading when wishlist.productIds.isEmpty =>
          const Center(child: LoadingIndicator()),
        WishlistStatus.failure when wishlist.productIds.isEmpty =>
          ErrorStateWidget(
            message: wishlist.message ?? 'Could not load your wishlist.',
            onRetry: () => ref.read(wishlistProvider.notifier).load(),
          ),
        _ when wishlist.productIds.isEmpty => const EmptyStateWidget(
          title: 'No saved items yet',
          message: 'Tap the heart on any product to save it here.',
          icon: Icons.favorite_border,
        ),
        _ => _grid(),
      },
    );
  }

  Widget _grid() {
    final productsAsync = ref.watch(wishlistProductsProvider);
    return productsAsync.when(
      loading: () => const Center(child: LoadingIndicator()),
      error: (_, _) => ErrorStateWidget(
        message: 'Could not load your saved products.',
        onRetry: () => ref.invalidate(wishlistProductsProvider),
      ),
      data: (products) {
        if (products.isEmpty) {
          return const EmptyStateWidget(
            title: 'No saved items yet',
            message: 'Tap the heart on any product to save it here.',
            icon: Icons.favorite_border,
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
      },
    );
  }
}
