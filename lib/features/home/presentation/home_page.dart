import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/providers/category_providers.dart';
import '../../chat/providers/chat_providers.dart';
import '../../products/domain/entities/product.dart';
import '../../products/providers/catalog_state.dart';
import '../../products/providers/product_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../wishlist/presentation/widgets/wishlist_product_card.dart';
import '../../wishlist/providers/wishlist_providers.dart';

/// Home surface: root categories and a featured products rail, wired to the
/// catalog providers.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (ref.read(sessionProvider).isAuthenticated) {
      ref.read(wishlistProvider.notifier).load();
      ref.read(notificationsProvider.notifier).load();
      ref.read(conversationsProvider.notifier).load();
    }
    await Future.wait([
      ref.read(categoriesProvider.notifier).loadRoots(),
      ref.read(productListProvider.notifier).loadFeatured(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productListProvider);

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'AURIVO',
        largeTitle: true,
        actions: [
          _CountBadgeIcon(
            tooltip: 'Messages',
            icon: Icons.chat_bubble_outline,
            count: ref.watch(unreadChatCountProvider),
            onPressed: () => context.push(AppRoutes.messages),
          ),
          _NotificationsBell(
            count: ref.watch(unreadNotificationsCountProvider),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SectionHeader(title: 'Shop by category'),
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 150, child: _categories(categories)),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Featured'),
            const SizedBox(height: AppSpacing.md),
            _featured(products),
          ],
        ),
      ),
    );
  }

  Widget _categories(CatalogState<List<Category>> state) {
    switch (state.status) {
      case CatalogViewStatus.initial:
      case CatalogViewStatus.loading:
        return const Center(child: LoadingIndicator());
      case CatalogViewStatus.failure:
        return Center(
          child: Text(
            state.message ?? 'Could not load categories.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      case CatalogViewStatus.success:
        final categories = state.data ?? const [];
        if (categories.isEmpty) {
          return Center(
            child: Text(
              'No categories yet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final category = categories[index];
            return SizedBox(
              width: 200,
              child: CategoryCard(
                title: category.name,
                imageUrl: category.imagePath ?? '',
                onTap: () => context.push(AppRoutes.explore),
              ),
            );
          },
        );
    }
  }

  Widget _featured(CatalogState<List<Product>> state) {
    switch (state.status) {
      case CatalogViewStatus.initial:
      case CatalogViewStatus.loading:
        return const Center(child: LoadingIndicator());
      case CatalogViewStatus.failure:
        return ErrorStateWidget(
          message: state.message ?? 'Could not load products.',
          onRetry: _load,
        );
      case CatalogViewStatus.success:
        final products = state.data ?? const [];
        if (products.isEmpty) {
          return const EmptyStateWidget(
            title: 'No featured products yet',
            message: 'Check back soon for our curated selection.',
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.62,
          ),
          itemBuilder: (context, index) => _productCard(products[index]),
        );
    }
  }

  Widget _productCard(Product product) => WishlistProductCard(product: product);
}

/// Bell icon with an unread-count badge, linking to the notification centre.
class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _CountBadgeIcon(
      tooltip: 'Notifications',
      icon: Icons.notifications_none_outlined,
      count: count,
      onPressed: onPressed,
    );
  }
}

/// An app-bar icon button with an optional unread-count badge.
class _CountBadgeIcon extends StatelessWidget {
  const _CountBadgeIcon({
    required this.tooltip,
    required this.icon,
    required this.count,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
    if (count == 0) return button;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      offset: const Offset(-4, 4),
      child: button,
    );
  }
}
