import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../orders/domain/entities/order_detail.dart';
import '../../orders/domain/entities/order_item.dart';
import '../../orders/domain/entities/order_status.dart';
import '../../orders/presentation/order_formatting.dart';
import '../../returns/presentation/order_return_card.dart';
import '../providers/admin_order_providers.dart';
import '../providers/admin_providers.dart';

/// Admin order detail + oversight controls: change status (audited history),
/// set payment status, and cancel (via admin_cancel_order, releasing stock).
class AdminOrderDetailPage extends ConsumerStatefulWidget {
  const AdminOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<AdminOrderDetailPage> createState() =>
      _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends ConsumerState<AdminOrderDetailPage> {
  // Statuses an admin can set via the audited history path (cancel is separate).
  static const _statusOptions = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.processing,
    OrderStatus.packed,
    OrderStatus.shipped,
    OrderStatus.delivered,
    OrderStatus.completed,
    OrderStatus.returned,
    OrderStatus.refunded,
  ];

  static const _paymentOptions = [
    PaymentStatus.pending,
    PaymentStatus.authorized,
    PaymentStatus.paid,
    PaymentStatus.failed,
    PaymentStatus.partiallyRefunded,
    PaymentStatus.refunded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(adminOrderDetailProvider(widget.orderId).notifier).load();

  Future<void> _report(Future<String?> action, String done) async {
    final error = await action;
    if (!mounted) return;
    error != null
        ? LuxurySnackBars.error(context, error)
        : LuxurySnackBars.success(context, done);
  }

  Future<void> _cancel(OrderDetail detail) async {
    final ok = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Cancel order?',
      message:
          'Cancel ${detail.order.orderNumber} and release reserved stock? '
          'This cannot be undone.',
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep',
    );
    if (ok != true) return;
    await _report(
      ref.read(adminOrderDetailProvider(widget.orderId).notifier).cancel(),
      'Order cancelled.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminOrderDetailProvider(widget.orderId));
    return Scaffold(
      appBar: LuxuryAppBar(
        title: async.valueOrNull?.order.orderNumber ?? 'Order',
        showBackButton: true,
      ),
      body: async.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load this order.',
          onRetry: _load,
        ),
        data: (detail) => _body(context, detail),
      ),
    );
  }

  Widget _body(BuildContext context, OrderDetail detail) {
    final theme = Theme.of(context);
    final order = detail.order;
    final access =
        ref.watch(staffAccessProvider).valueOrNull ?? const StaffAccess();
    // Status / payment / cancel changes are admin-only (RLS); support and
    // finance staff get a read-only view plus their return/refund actions.
    final canChange = access.canChangeOrders;
    final canCancel =
        canChange &&
        (order.status == OrderStatus.pending ||
            order.status == OrderStatus.confirmed);
    final returnViewer = access.isAdmin
        ? ReturnViewer.admin
        : access.isFinance
        ? ReturnViewer.finance
        : ReturnViewer.support;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              LuxuryBadge(label: OrderStatus.label(order.status)),
            ],
          ),
          if (order.placedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Placed ${formatOrderDate(order.placedAt!)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          OrderReturnCard(
            orderId: order.id,
            orderStatus: order.status,
            viewer: returnViewer,
            onChanged: _load,
          ),
          const SizedBox(height: AppSpacing.lg),

          _Section(
            title: 'Ship to',
            child: _AddressBlock(snapshot: order.shippingAddressSnapshot),
          ),
          const SizedBox(height: AppSpacing.md),

          _Section(
            title: 'Items',
            child: Column(
              children: [
                for (final item in detail.items) _ItemRow(item: item),
                const Divider(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand total', style: theme.textTheme.titleSmall),
                    PriceWidget(
                      price: order.grandTotal,
                      currency: order.currency,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _Section(
            title: 'Payment',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  detail.payment == null
                      ? 'No payment record'
                      : PaymentStatus.label(detail.payment!.status),
                  style: theme.textTheme.bodyMedium,
                ),
                if (detail.payment != null && canChange)
                  DropdownButton<String>(
                    value: detail.payment!.status,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final s in _paymentOptions)
                        DropdownMenuItem(
                          value: s,
                          child: Text(PaymentStatus.label(s)),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null || v == detail.payment!.status) return;
                      _report(
                        ref
                            .read(
                              adminOrderDetailProvider(widget.orderId).notifier,
                            )
                            .setPaymentStatus(v),
                        'Payment updated.',
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _Section(
            title: 'Shipments',
            child: detail.shipments.isEmpty
                ? Text('No shipment yet.', style: theme.textTheme.bodyMedium)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in detail.shipments)
                        Text(
                          '${ShipmentStatus.label(s.status)}'
                          '${s.courier != null ? ' · ${s.courier}' : ''}'
                          '${s.trackingNumber != null ? ' · ${s.trackingNumber}' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),

          _Section(
            title: 'Status timeline',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in detail.statusHistory)
                  Text(
                    '${OrderStatus.label(e.status)}'
                    '${e.createdAt != null ? ' — ${formatOrderDateTime(e.createdAt!)}' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (detail.statusHistory.isEmpty)
                  Text('No history.', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (canChange) ...[
            Text('Change status', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _statusOptions.contains(order.status)
                  ? order.status
                  : null,
              decoration: const InputDecoration(labelText: 'Set order status'),
              items: [
                for (final s in _statusOptions)
                  DropdownMenuItem(value: s, child: Text(OrderStatus.label(s))),
              ],
              onChanged: (v) {
                if (v == null || v == order.status) return;
                _report(
                  ref
                      .read(adminOrderDetailProvider(widget.orderId).notifier)
                      .advanceStatus(v),
                  'Status updated.',
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          if (canCancel)
            SizedBox(
              width: double.infinity,
              child: LuxuryOutlinedButton(
                label: 'Cancel order',
                onPressed: () => _cancel(detail),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({required this.snapshot});

  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    String? read(String key) {
      final v = snapshot[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final theme = Theme.of(context);
    final name = read('recipient_name');
    final phone = read('phone');
    final lines = <String>[
      if (read('address_line_1') != null) read('address_line_1')!,
      if (read('address_line_2') != null) read('address_line_2')!,
      if ([read('city'), read('province')].any((e) => e != null))
        [read('city'), read('province')].where((e) => e != null).join(', '),
    ];
    if (name == null && phone == null && lines.isEmpty) {
      return Text('No shipping details.', style: theme.textTheme.bodyMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null) Text(name, style: theme.textTheme.bodyMedium),
        if (phone != null) Text(phone, style: theme.textTheme.bodySmall),
        for (final l in lines) Text(l, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productTitleSnapshot,
                  style: theme.textTheme.bodyMedium,
                ),
                Text('Qty ${item.quantity}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          PriceWidget(price: item.lineTotal, currency: item.currency),
        ],
      ),
    );
  }
}
