import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/seller_product.dart';
import '../providers/seller_product_providers.dart';
import '../providers/seller_providers.dart' show SellerViewStatus;

/// Seller Studio home: the seller's own products (all statuses), with create /
/// edit / publish / delete actions. Gated on the user having a seller store.
class SellerDashboardPage extends ConsumerWidget {
  const SellerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(mySellerProfileIdProvider);
    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Seller Studio',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Orders',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(AppRoutes.sellerOrders),
          ),
          IconButton(
            tooltip: 'Quote requests',
            icon: const Icon(Icons.request_quote_outlined),
            onPressed: () => context.push(AppRoutes.sellerRfqInbox),
          ),
        ],
      ),
      body: sellerAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load your seller store.',
          onRetry: () => ref.invalidate(mySellerProfileIdProvider),
        ),
        data: (sellerId) =>
            sellerId == null ? const _NotASeller() : const _MyProductsView(),
      ),
    );
  }
}

class _NotASeller extends StatelessWidget {
  const _NotASeller();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      title: 'No seller store yet',
      message:
          'You need a verified seller store to list products. Seller onboarding '
          'is managed from your profile.',
      icon: Icons.storefront_outlined,
    );
  }
}

class _MyProductsView extends ConsumerStatefulWidget {
  const _MyProductsView();

  @override
  ConsumerState<_MyProductsView> createState() => _MyProductsViewState();
}

class _MyProductsViewState extends ConsumerState<_MyProductsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(myProductsProvider.notifier).load();

  Future<void> _publish(SellerProduct p, bool publish) async {
    final error = await ref
        .read(myProductsProvider.notifier)
        .setPublished(p.id, publish);
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(
        context,
        publish ? 'Submitted for review.' : 'Product unpublished.',
      );
    }
  }

  Future<void> _delete(SellerProduct p) async {
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete product?',
      message: 'This removes "${p.title}" from your store.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (confirmed != true || !mounted) return;
    final error = await ref.read(myProductsProvider.notifier).softDelete(p.id);
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(context, 'Product deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProductsProvider);
    final products = state.data ?? const [];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.sellerProductNew),
        icon: const Icon(Icons.add),
        label: const Text('New product'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          SellerViewStatus.initial || SellerViewStatus.loading
              when state.data == null =>
            const Center(child: LoadingIndicator()),
          SellerViewStatus.failure when state.data == null => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load your products.',
                onRetry: _load,
              ),
            ],
          ),
          _ =>
            products.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(
                        title: 'No products yet',
                        message: 'Tap "New product" to list your first item.',
                        icon: Icons.diamond_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: products.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductTile(
                        product: product,
                        onEdit: () => context.push(
                          AppRoutes.sellerProductEditPath(product.id),
                        ),
                        onTogglePublish: () =>
                            _publish(product, !product.isPublished),
                        onDelete: () => _delete(product),
                      );
                    },
                  ),
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onDelete,
  });

  final SellerProduct product;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      onTap: onEdit,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    LuxuryBadge(
                      label: ProductStatus.label(product.status),
                      backgroundColor: product.isPublished
                          ? AppColors.primaryGold
                          : AppColors.softGrey,
                      foregroundColor: product.isPublished
                          ? AppColors.pureWhite
                          : AppColors.charcoal,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                PriceWidget(
                  price: product.basePrice,
                  originalPrice: product.comparePrice,
                  currency: product.currency,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'publish':
                  onTogglePublish();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'publish',
                child: Text(
                  product.isPublished ? 'Unpublish' : 'Submit for review',
                ),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
