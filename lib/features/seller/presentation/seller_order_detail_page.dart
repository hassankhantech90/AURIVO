import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../orders/domain/entities/order_item.dart';
import '../../orders/domain/entities/order_status.dart';
import '../../orders/presentation/order_formatting.dart';
import '../../disputes/presentation/order_dispute_entry.dart';
import '../../returns/presentation/order_return_card.dart';
import '../domain/entities/seller_order_detail.dart';
import '../providers/seller_order_providers.dart';
import '../providers/seller_providers.dart' show SellerViewStatus;
import 'widgets/shipment_form_sheet.dart';

/// Seller-side fulfilment view for a single order: the shipping address, the
/// seller's own line items, the shipment, and actions to advance fulfilment.
class SellerOrderDetailPage extends ConsumerStatefulWidget {
  const SellerOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<SellerOrderDetailPage> createState() =>
      _SellerOrderDetailPageState();
}

class _SellerOrderDetailPageState extends ConsumerState<SellerOrderDetailPage> {
  // Guards the fulfilment buttons against a double-tap that would append a
  // duplicate status-history row (and, for `shipped`, a duplicate buyer
  // notification).
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(sellerOrderDetailProvider(widget.orderId).notifier).load();

  Future<void> _advance(String status, String doneLabel) async {
    if (_advancing) return;
    setState(() => _advancing = true);
    final error = await ref
        .read(sellerOrderDetailProvider(widget.orderId).notifier)
        .advanceStatus(status);
    if (!mounted) return;
    setState(() => _advancing = false);
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      ref.invalidate(sellerOrdersProvider); // keep the inbox status in sync
      LuxurySnackBars.success(context, doneLabel);
    }
  }

  Future<void> _manageShipment(SellerOrderDetail detail) async {
    final saved = await ShipmentFormSheet.show(
      context,
      orderId: widget.orderId,
      initial: detail.shipment,
    );
    if (saved == true && mounted) {
      ref.invalidate(sellerOrdersProvider);
      LuxurySnackBars.success(context, 'Shipment saved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerOrderDetailProvider(widget.orderId));
    final detail = state.data;

    return Scaffold(
      appBar: LuxuryAppBar(
        title: detail?.orderNumber ?? 'Order',
        showBackButton: true,
      ),
      body: switch (state.status) {
        SellerViewStatus.initial || SellerViewStatus.loading
            when detail == null =>
          const Center(child: LoadingIndicator()),
        SellerViewStatus.failure when detail == null => ErrorStateWidget(
          message: state.message ?? 'Could not load this order.',
          onRetry: _load,
        ),
        _ when detail == null => const Center(child: LoadingIndicator()),
        _ => _body(context, detail),
      },
    );
  }

  Widget _body(BuildContext context, SellerOrderDetail detail) {
    final theme = Theme.of(context);
    final terminal = OrderStatus.isTerminal(detail.status);
    final s = detail.status;
    final canPack =
        !terminal &&
        (s == OrderStatus.pending ||
            s == OrderStatus.confirmed ||
            s == OrderStatus.processing);
    final canShip = !terminal && s != OrderStatus.shipped && s != OrderStatus.delivered;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.orderNumber,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              LuxuryBadge(label: OrderStatus.label(detail.status)),
            ],
          ),
          if (detail.placedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Placed ${formatOrderDate(detail.placedAt!)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          OrderReturnCard(
            orderId: widget.orderId,
            orderStatus: detail.status,
            viewer: ReturnViewer.seller,
            onChanged: () {
              _load();
              ref.invalidate(sellerOrdersProvider);
            },
          ),
          OrderDisputeEntry(orderId: widget.orderId, orderStatus: detail.status),
          const SizedBox(height: AppSpacing.lg),

          _SectionCard(
            title: 'Ship to',
            child: _AddressBlock(snapshot: detail.shippingAddress),
          ),
          const SizedBox(height: AppSpacing.md),

          _SectionCard(
            title: 'Your items',
            child: Column(
              children: [
                for (final item in detail.items) _ItemRow(item: item),
                const Divider(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your subtotal',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Bound the price so its FittedBox(scaleDown) can shrink a
                    // wide PKR total at large text scales instead of overflowing.
                    Flexible(
                      child: PriceWidget(
                        price: detail.sellerSubtotal,
                        currency: detail.currency,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _SectionCard(
            title: 'Shipment',
            child: detail.shipment == null
                ? Text(
                    'No shipment yet.',
                    style: theme.textTheme.bodyMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${ShipmentStatus.label(detail.shipment!.status)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (detail.shipment!.courier != null)
                        Text(
                          'Courier: ${detail.shipment!.courier}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (detail.shipment!.trackingNumber != null)
                        Text(
                          'Tracking: ${detail.shipment!.trackingNumber}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (!terminal) ...[
            Text('Fulfilment', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (canPack)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: LuxuryOutlinedButton(
                  label: 'Mark as packed',
                  onPressed: _advancing
                      ? null
                      : () => _advance(OrderStatus.packed, 'Marked packed.'),
                ),
              ),
            if (canShip)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: LuxuryOutlinedButton(
                  label: 'Mark as shipped',
                  onPressed: _advancing
                      ? null
                      : () => _advance(OrderStatus.shipped, 'Marked shipped.'),
                ),
              ),
            PrimaryButton(
              label: detail.shipment == null
                  ? 'Add shipment details'
                  : 'Update shipment',
              onPressed: () => _manageShipment(detail),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

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

    final name = read('recipient_name');
    final phone = read('phone');
    final lines = <String>[
      if (read('address_line_1') != null) read('address_line_1')!,
      if (read('address_line_2') != null) read('address_line_2')!,
      if ([read('city'), read('province')].any((e) => e != null))
        [read('city'), read('province')].where((e) => e != null).join(', '),
    ];

    final theme = Theme.of(context);
    if (name == null && phone == null && lines.isEmpty) {
      return Text('No shipping details.', style: theme.textTheme.bodyMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null) Text(name, style: theme.textTheme.bodyMedium),
        if (phone != null) Text(phone, style: theme.textTheme.bodySmall),
        for (final line in lines)
          Text(line, style: theme.textTheme.bodySmall),
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
                if (item.variantTitleSnapshot != null)
                  Text(
                    item.variantTitleSnapshot!,
                    style: theme.textTheme.bodySmall,
                  ),
                Text('Qty ${item.quantity}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: PriceWidget(price: item.lineTotal, currency: item.currency),
          ),
        ],
      ),
    );
  }
}
