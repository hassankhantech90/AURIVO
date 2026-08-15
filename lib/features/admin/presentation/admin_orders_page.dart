import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../orders/domain/entities/order.dart';
import '../../orders/domain/entities/order_status.dart';
import '../../orders/presentation/order_formatting.dart';
import '../providers/admin_order_providers.dart';
import '../providers/admin_providers.dart' show AdminStatus;

/// Admin order oversight: all orders with a status filter and order-number
/// search; tap through to the detail + controls.
class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() => ref.read(adminOrdersProvider.notifier).load();

  List<Order> _filter(List<Order> orders) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return orders;
    return orders
        .where((o) => o.orderNumber.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminOrdersProvider);
    final active = ref.watch(
      adminOrdersProvider.notifier.select((n) => n.statusFilter),
    );
    final orders = _filter(state.data);

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Orders',
        showBackButton: true,
        searchController: _search,
        searchHint: 'Search order number',
        onSearchChanged: (_) => setState(() {}),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: active == null,
                  onTap: () => ref
                      .read(adminOrdersProvider.notifier)
                      .load(status: null, setFilter: true),
                ),
                for (final s in OrderStatus.all)
                  _FilterChip(
                    label: OrderStatus.label(s),
                    selected: active == s,
                    onTap: () => ref
                        .read(adminOrdersProvider.notifier)
                        .load(status: s, setFilter: true),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: switch (state.status) {
                AdminStatus.initial ||
                AdminStatus.loading when state.data.isEmpty =>
                  const Center(child: LoadingIndicator()),
                AdminStatus.failure when state.data.isEmpty => ListView(
                  children: [
                    const SizedBox(height: 80),
                    ErrorStateWidget(
                      message: state.message ?? 'Could not load orders.',
                      onRetry: _load,
                    ),
                  ],
                ),
                _ when orders.isEmpty => ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyStateWidget(
                      title: 'No orders',
                      message: 'No orders match this filter.',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                ),
                _ => ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _OrderTile(
                    order: orders[index],
                    onTap: () => context.push(
                      AppRoutes.adminOrderDetailPath(orders[index].id),
                    ),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Center(
        child: LuxuryChip(label: label, selected: selected, onTap: onTap),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});

  final Order order;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.placedAt == null
                    ? PaymentStatus.label(order.paymentStatus)
                    : '${formatOrderDate(order.placedAt!)} · '
                          '${PaymentStatus.label(order.paymentStatus)}',
                style: theme.textTheme.bodySmall,
              ),
              PriceWidget(price: order.grandTotal, currency: order.currency),
            ],
          ),
        ],
      ),
    );
  }
}
