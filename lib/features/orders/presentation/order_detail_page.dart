import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../reviews/presentation/widgets/review_form_sheet.dart';
import '../../reviews/providers/review_providers.dart';
import '../../seller/providers/seller_providers.dart';
import '../domain/entities/order.dart';
import '../domain/entities/order_detail.dart';
import '../domain/entities/order_item.dart';
import '../domain/entities/order_status.dart';
import '../domain/entities/order_status_event.dart';
import '../domain/entities/payment.dart';
import '../domain/entities/shipment.dart';
import '../domain/entities/tracking_event.dart';
import '../providers/order_providers.dart';
import 'order_formatting.dart';
import 'order_status_badge.dart';

/// Read-only detail view for a single order: items, totals, shipping snapshot,
/// payment, status timeline, and shipments/tracking. Cancellation (when the
/// order is still eligible) is delegated to the `cancel_order` RPC via the
/// provider — the buyer app performs no direct writes.
class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(orderDetailProvider(widget.orderId).notifier).load();

  Future<void> _confirmCancel() async {
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Cancel order?',
      message:
          'This will cancel your order and release the reserved items. This '
          'cannot be undone.',
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep order',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final ok = await ref
        .read(orderDetailProvider(widget.orderId).notifier)
        .cancel(reason: 'Cancelled by customer');
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (ok) {
      LuxurySnackBars.success(context, 'Your order has been cancelled.');
    } else {
      final message =
          ref.read(orderDetailProvider(widget.orderId)).message ??
          'Could not cancel your order.';
      LuxurySnackBars.error(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderDetailProvider(widget.orderId));
    final detail = state.data;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Order', showBackButton: true),
      body: switch (state.status) {
        OrderViewStatus.initial || OrderViewStatus.loading
            when detail == null =>
          const Center(child: LoadingIndicator()),
        OrderViewStatus.failure when detail == null => ErrorStateWidget(
          message: state.message ?? 'Could not load this order.',
          onRetry: _load,
        ),
        _ =>
          detail == null
              ? const Center(child: LoadingIndicator())
              : _OrderDetailBody(
                  detail: detail,
                  cancelling: _cancelling,
                  onCancel: _confirmCancel,
                ),
      },
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({
    required this.detail,
    required this.cancelling,
    required this.onCancel,
  });

  final OrderDetail detail;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final order = detail.order;
    // A buyer may review a purchased item once the order has been fulfilled;
    // passing the order_item_id lets the DB trigger set `verified_purchase`.
    final reviewable =
        order.status == OrderStatus.delivered ||
        order.status == OrderStatus.completed;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeaderCard(order: order),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(
          title: 'Items',
          child: Column(
            children: [
              for (final item in detail.items)
                _OrderItemRow(item: item, reviewable: reviewable),
            ],
          ),
        ),
        if (reviewable && _sellerIds(detail).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Rate the sellers',
            child: Column(
              children: [
                for (final sellerId in _sellerIds(detail))
                  _SellerReviewEntry(sellerId: sellerId),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _SummaryCard(order: order),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(
          title: 'Shipping address',
          child: _AddressSnapshot(snapshot: order.shippingAddressSnapshot),
        ),
        if (detail.payment != null) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Payment',
            child: _PaymentInfo(payment: detail.payment!),
          ),
        ],
        if (detail.statusHistory.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Status history',
            child: Column(
              children: [
                for (final event in detail.statusHistory)
                  _StatusEventRow(event: event),
              ],
            ),
          ),
        ],
        if (detail.shipments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Shipments',
            child: Column(
              children: [
                for (final shipment in detail.shipments)
                  _ShipmentBlock(
                    shipment: shipment,
                    events: detail.eventsForShipment(shipment.id),
                  ),
              ],
            ),
          ),
        ],
        if (order.notes != null && order.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Order note',
            child: Text(
              order.notes!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        if (order.isCancellable) ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: LuxuryOutlinedButton(
              label: 'Cancel order',
              isLoading: cancelling,
              onPressed: cancelling ? null : onCancel,
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OrderStatusBadge(status: order.status),
            ],
          ),
          if (order.placedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Placed ${formatOrderDateTime(order.placedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            PaymentStatus.label(order.paymentStatus),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Distinct seller ids across the order's items, preserving first-seen order.
List<String> _sellerIds(OrderDetail detail) {
  final seen = <String>{};
  final ids = <String>[];
  for (final item in detail.items) {
    if (seen.add(item.sellerId)) ids.add(item.sellerId);
  }
  return ids;
}

/// Entry point to review a seller from a fulfilled order. Shown only when the
/// seller is a publicly visible (verified) storefront; navigates to the
/// storefront, where the buyer writes the review (server sets verified_purchase
/// from their delivered/completed orders with that seller).
class _SellerReviewEntry extends ConsumerWidget {
  const _SellerReviewEntry({required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(sellerByIdProvider(sellerId)).valueOrNull;
    if (seller == null) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.storefront_outlined,
        color: AppColors.primaryGold,
      ),
      title: Text(seller.storeName),
      trailing: const Icon(Icons.chevron_right, color: AppColors.softGrey),
      onTap: () => context.push(AppRoutes.sellerDetailPath(seller.slug)),
    );
  }
}

class _OrderItemRow extends ConsumerWidget {
  const _OrderItemRow({required this.item, this.reviewable = false});

  final OrderItem item;
  final bool reviewable;

  Future<void> _openReview(BuildContext context, WidgetRef ref) async {
    final existing = ref
        .read(myProductReviewProvider(item.productId))
        .valueOrNull;
    final saved = await ReviewFormSheet.show(
      context,
      productId: item.productId,
      orderItemId: item.id,
      initialReview: existing,
    );
    if (saved == true) {
      ref.invalidate(myProductReviewProvider(item.productId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleParts = <String>[
      if (item.variantTitleSnapshot != null &&
          item.variantTitleSnapshot!.isNotEmpty)
        item.variantTitleSnapshot!,
      'SKU ${item.skuSnapshot}',
    ];
    final hasReview =
        reviewable &&
        ref.watch(myProductReviewProvider(item.productId)).valueOrNull != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productTitleSnapshot,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitleParts.join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${item.quantity} × ${item.currency} '
                      '${item.unitPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${item.currency} ${item.lineTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          if (reviewable)
            Align(
              alignment: Alignment.centerLeft,
              child: LuxuryTextButton(
                label: hasReview ? 'Edit review' : 'Write a review',
                onPressed: () => _openReview(context, ref),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Order summary',
      child: Column(
        children: [
          _AmountRow(
            label: 'Subtotal',
            amount: order.subtotal,
            currency: order.currency,
          ),
          if (order.shippingFee > 0)
            _AmountRow(
              label: 'Shipping',
              amount: order.shippingFee,
              currency: order.currency,
            ),
          if (order.taxTotal > 0)
            _AmountRow(
              label: 'Tax',
              amount: order.taxTotal,
              currency: order.currency,
            ),
          if (order.discountTotal > 0)
            _AmountRow(
              label: 'Discount',
              amount: -order.discountTotal,
              currency: order.currency,
            ),
          const LuxuryDivider(height: AppSpacing.lg),
          _AmountRow(
            label: 'Total',
            amount: order.grandTotal,
            currency: order.currency,
            emphasise: true,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    required this.currency,
    this.emphasise = false,
  });

  final String label;
  final double amount;
  final String currency;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final style = emphasise
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$currency ${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class _AddressSnapshot extends StatelessWidget {
  const _AddressSnapshot({required this.snapshot});

  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    String? read(String key) {
      final value = snapshot[key];
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final name = read('recipient_name');
    final phone = read('phone');
    final lines = <String>[
      if (read('address_line_1') != null) read('address_line_1')!,
      if (read('address_line_2') != null) read('address_line_2')!,
      if (read('area') != null) read('area')!,
      [read('city'), read('province')].where((e) => e != null).join(', '),
      if (read('postal_code') != null) read('postal_code')!,
      if (read('country') != null) read('country')!,
    ].where((e) => e.isNotEmpty).toList();

    if (name == null && phone == null && lines.isEmpty) {
      return Text(
        'No address on file.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null)
          Text(name, style: Theme.of(context).textTheme.titleSmall),
        if (phone != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(phone, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (lines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(lines.join(', '), style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _PaymentInfo extends StatelessWidget {
  const _PaymentInfo({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              PaymentMethod.label(payment.method),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              PaymentStatus.label(payment.status),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (payment.paidAt != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Paid ${formatOrderDateTime(payment.paidAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _StatusEventRow extends StatelessWidget {
  const _StatusEventRow({required this.event});

  final OrderStatusEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3, right: AppSpacing.sm),
            child: Icon(Icons.circle, size: 10, color: AppColors.primaryGold),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  OrderStatus.label(event.status),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (event.notes != null && event.notes!.isNotEmpty)
                  Text(
                    event.notes!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (event.createdAt != null)
                  Text(
                    formatOrderDateTime(event.createdAt!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipmentBlock extends StatelessWidget {
  const _ShipmentBlock({required this.shipment, required this.events});

  final Shipment shipment;
  final List<TrackingEvent> events;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shipment.courier ?? 'Shipment',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              LuxuryBadge(
                label: ShipmentStatus.label(shipment.status),
                backgroundColor: AppColors.porcelain,
                foregroundColor: AppColors.charcoal,
              ),
            ],
          ),
          if (shipment.trackingNumber != null &&
              shipment.trackingNumber!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tracking: ${shipment.trackingNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '• ${ShipmentStatus.label(event.status)}'
                '${event.location != null ? ' — ${event.location}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

// Shared shells --------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}
