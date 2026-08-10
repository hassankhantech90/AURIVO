import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/order.dart';
import '../domain/entities/order_status.dart';
import '../providers/order_providers.dart';
import 'order_formatting.dart';
import 'order_status_badge.dart';

/// Buyer's order history, backed by [ordersProvider] (RLS-scoped to the signed-in
/// profile). Read-only list; tapping an order opens its detail.
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(ordersProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    final orders = state.data;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'My Orders', showBackButton: true),
      body: switch (state.status) {
        OrderViewStatus.initial || OrderViewStatus.loading
            when orders == null =>
          const Center(child: LoadingIndicator()),
        OrderViewStatus.failure when orders == null => ErrorStateWidget(
          message: state.message ?? 'Could not load your orders.',
          onRetry: _load,
        ),
        _ =>
          orders == null || orders.isEmpty
              ? const EmptyStateWidget(
                  title: 'No orders yet',
                  message: 'Your placed orders will appear here.',
                  icon: Icons.receipt_long_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _OrderCard(order: orders[index]),
                  ),
                ),
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push(AppRoutes.orderDetailPath(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (order.placedAt != null)
                Text(
                  formatOrderDate(order.placedAt!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    PaymentStatus.label(order.paymentStatus),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  PriceWidget(
                    price: order.grandTotal,
                    currency: order.currency,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
