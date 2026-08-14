import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../orders/domain/entities/order_status.dart';
import '../../orders/presentation/order_formatting.dart';
import '../domain/entities/seller_order_summary.dart';
import '../providers/seller_order_providers.dart';
import '../providers/seller_providers.dart' show SellerViewStatus;

/// Seller Studio → Orders inbox: every order containing at least one of the
/// seller's products. Backed by the `seller_orders()` RPC (RLS-safe).
class SellerOrdersPage extends ConsumerStatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  ConsumerState<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends ConsumerState<SellerOrdersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(sellerOrdersProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerOrdersProvider);
    final orders = state.data ?? const [];

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Orders', showBackButton: true),
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
                message: state.message ?? 'Could not load your orders.',
                onRetry: _load,
              ),
            ],
          ),
          _ =>
            orders.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(
                        title: 'No orders yet',
                        message: 'Orders that include your products appear here.',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) => _OrderTile(
                      order: orders[index],
                      onTap: () => context.push(
                        AppRoutes.sellerOrderDetailPath(orders[index].orderId),
                      ),
                    ),
                  ),
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});

  final SellerOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              LuxuryBadge(label: OrderStatus.label(order.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (order.placedAt != null)
            Text(
              formatOrderDate(order.placedAt!),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall,
              ),
              PriceWidget(
                price: order.sellerSubtotal,
                currency: order.currency,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
