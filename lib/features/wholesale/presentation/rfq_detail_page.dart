import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../chat/presentation/widgets/message_seller_button.dart';
import '../domain/entities/quote.dart';
import '../domain/entities/rfq.dart';
import '../domain/entities/rfq_detail.dart';
import '../domain/entities/rfq_status.dart';
import '../providers/rfq_providers.dart';
import 'widgets/address_picker_sheet.dart';
import 'widgets/quote_tile.dart';

/// Detail for a single RFQ: the request summary plus the quotes received. The
/// buyer may cancel while the request is still active, and accept a live quote
/// on a product-linked request — which converts it into an order.
class RfqDetailPage extends ConsumerStatefulWidget {
  const RfqDetailPage({super.key, required this.rfqId});

  final String rfqId;

  @override
  ConsumerState<RfqDetailPage> createState() => _RfqDetailPageState();
}

class _RfqDetailPageState extends ConsumerState<RfqDetailPage> {
  bool _cancelling = false;
  String? _acceptingQuoteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(rfqDetailProvider(widget.rfqId).notifier).load();

  Future<void> _accept(Quote quote) async {
    final addressId = await AddressPickerSheet.show(context);
    if (addressId == null || !mounted) return;

    setState(() => _acceptingQuoteId = quote.id);
    final orderId = await ref
        .read(rfqDetailProvider(widget.rfqId).notifier)
        .accept(quoteId: quote.id, addressId: addressId);
    if (!mounted) return;
    setState(() => _acceptingQuoteId = null);

    if (orderId != null) {
      LuxurySnackBars.success(context, 'Order placed from the accepted quote.');
      context.push(AppRoutes.orderDetailPath(orderId));
    } else {
      final message =
          ref.read(rfqDetailProvider(widget.rfqId)).message ??
          'Could not accept the quote.';
      LuxurySnackBars.error(context, message);
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Cancel request?',
      message: 'This will withdraw your quote request. This cannot be undone.',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final ok = await ref
        .read(rfqDetailProvider(widget.rfqId).notifier)
        .cancel();
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (ok) {
      LuxurySnackBars.success(context, 'Your request has been cancelled.');
    } else {
      final message =
          ref.read(rfqDetailProvider(widget.rfqId)).message ??
          'Could not cancel your request.';
      LuxurySnackBars.error(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rfqDetailProvider(widget.rfqId));
    final detail = state.data;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Quote request', showBackButton: true),
      body: switch (state.status) {
        RfqViewStatus.initial || RfqViewStatus.loading when detail == null =>
          const Center(child: LoadingIndicator()),
        RfqViewStatus.failure when detail == null => ErrorStateWidget(
          message: state.message ?? 'Could not load this request.',
          onRetry: _load,
        ),
        _ =>
          detail == null
              ? const Center(child: LoadingIndicator())
              : _RfqDetailBody(
                  detail: detail,
                  cancelling: _cancelling,
                  onCancel: _confirmCancel,
                  onAccept: _accept,
                  acceptingQuoteId: _acceptingQuoteId,
                ),
      },
    );
  }
}

class _RfqDetailBody extends StatelessWidget {
  const _RfqDetailBody({
    required this.detail,
    required this.cancelling,
    required this.onCancel,
    required this.onAccept,
    required this.acceptingQuoteId,
  });

  final RfqDetail detail;
  final bool cancelling;
  final VoidCallback onCancel;
  final void Function(Quote quote) onAccept;
  final String? acceptingQuoteId;

  /// A live quote on a still-open, product-linked request can be accepted.
  bool _canAccept(Rfq rfq, Quote quote) {
    final validNow =
        quote.validUntil == null || quote.validUntil!.isAfter(DateTime.now());
    return rfq.productId != null &&
        (rfq.status == RfqStatus.open || rfq.status == RfqStatus.quoted) &&
        quote.status == QuoteStatus.sent &&
        validNow;
  }

  @override
  Widget build(BuildContext context) {
    final Rfq rfq = detail.rfq;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        LuxuryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quantity ${rfq.quantity}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  LuxuryBadge(
                    label: RfqStatus.label(rfq.status),
                    backgroundColor: AppColors.porcelain,
                    foregroundColor: AppColors.charcoal,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                rfq.targetPrice != null
                    ? 'Target ${rfq.currency} ${rfq.targetPrice!.toStringAsFixed(2)} / unit'
                    : 'No target price specified',
                style: theme.textTheme.bodySmall,
              ),
              if (rfq.message != null && rfq.message!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(rfq.message!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (rfq.sellerProfileId != null) ...[
          const SizedBox(height: AppSpacing.md),
          MessageSellerButton(
            sellerProfileId: rfq.sellerProfileId!,
            rfqId: rfq.id,
            label: 'Message seller',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Quotes received', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (!detail.hasQuotes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'No quotes yet. Sellers will respond to your request here.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final quote in detail.quotes) ...[
            QuoteTile(
              quote: quote,
              onAccept: _canAccept(rfq, quote) ? () => onAccept(quote) : null,
              busy: acceptingQuoteId == quote.id,
            ),
            const LuxuryDivider(),
          ],
        if (rfq.isCancellable) ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: LuxuryOutlinedButton(
              label: 'Cancel request',
              isLoading: cancelling,
              onPressed: cancelling ? null : onCancel,
            ),
          ),
        ],
      ],
    );
  }
}
