import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../../cart/providers/cart_providers.dart';
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
        titleWidget: const _BrandTitle(),
        toolbarHeight: 74,
        actions: [
          _CountBadgeIcon(
            tooltip: 'Cart',
            icon: Icons.shopping_bag_outlined,
            // Reflects the existing cart state's item count; a read only — it
            // never triggers a cart load or write from Home.
            count: ref.watch(cartProvider.select((s) => s.itemCount)),
            onPressed: () => context.push(AppRoutes.cart),
          ),
          _NotificationsBell(
            count: ref.watch(unreadNotificationsCountProvider),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          // Secondary destinations live in an overflow menu to keep the header
          // clean (they move to the bottom nav when that lands).
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'messages') {
                context.push(AppRoutes.messages);
              } else if (value == 'settings') {
                context.push(AppRoutes.settings);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'messages',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline),
                    SizedBox(width: AppSpacing.md),
                    Text('Messages'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: AppSpacing.md),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SectionHeader(title: 'Shop by metal'),
            const SizedBox(height: AppSpacing.md),
            const _MetalTabs(),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Shop by category'),
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 180, child: _categories(categories)),
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
                // Filter Explore by this root category's subtree. Encode the id
                // as a query parameter rather than concatenating a raw string.
                onTap: () => context.push(
                  Uri(
                    path: AppRoutes.explore,
                    queryParameters: {'category': category.id},
                  ).toString(),
                ),
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

/// The AURIVO wordmark with the marketplace tagline, for the Home app bar.
class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AURIVO', style: theme.textTheme.headlineSmall),
        // Scale-down guard so the letter-spaced tagline never overflows next to
        // the app-bar actions on narrow phones / large text scales.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'THE JEWELLERY MARKETPLACE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.mediumGrey,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The pilot's fixed metal taxonomy, surfaced as Home filter tabs. Each opens
/// Explore filtered to that metal (mirrors the category-card → Explore flow).
const _metals = ['Gold', 'Silver', 'Artificial'];

/// Horizontal row of metal filter chips. Tapping a metal browses Explore
/// filtered by that metal via a `material` query parameter.
class _MetalTabs extends StatelessWidget {
  const _MetalTabs();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final metal in _metals)
          LuxuryChip(
            label: metal,
            onTap: () => context.push(
              Uri(
                path: AppRoutes.explore,
                queryParameters: {'material': metal},
              ).toString(),
            ),
          ),
      ],
    );
  }
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
