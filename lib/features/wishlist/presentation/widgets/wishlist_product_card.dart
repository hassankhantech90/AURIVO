import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/design_system.dart';
import '../../../authentication/providers/session_provider.dart';
import '../../../products/domain/entities/product.dart';
import '../../providers/wishlist_providers.dart';

/// A [ProductCard] with its favourite toggle wired to [wishlistProvider].
///
/// Guests are routed to sign-in rather than silently failing the RLS-protected
/// write. Ownership is enforced server-side; this only toggles the current
/// user's own wishlist.
class WishlistProductCard extends ConsumerWidget {
  const WishlistProductCard({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    if (!ref.read(sessionProvider).isAuthenticated) {
      LuxurySnackBars.info(context, 'Sign in to save items to your wishlist.');
      context.push(AppRoutes.login);
      return;
    }
    await ref.read(wishlistProvider.notifier).toggle(product.id);
    if (!context.mounted) return;
    final state = ref.read(wishlistProvider);
    if (state.status == WishlistStatus.failure) {
      LuxurySnackBars.error(
        context,
        state.message ?? 'Could not update your wishlist.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavourite = ref.watch(
      wishlistProvider.select((s) => s.contains(product.id)),
    );
    return ProductCard(
      name: product.title,
      price: product.basePrice,
      originalPrice: product.comparePrice,
      currency: product.currency,
      imageUrl: product.primaryImageUrl ?? '',
      isFavourite: isFavourite,
      onTap: onTap ?? () => context.push(AppRoutes.productPath(product.id)),
      onFavouritePressed: () => _toggle(context, ref),
    );
  }
}
