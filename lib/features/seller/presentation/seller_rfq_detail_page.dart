import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../wholesale/domain/entities/rfq.dart';
import '../../wholesale/domain/entities/rfq_status.dart';
import '../../wholesale/presentation/widgets/quote_tile.dart';
import '../domain/entities/seller_rfq_view.dart';
import '../providers/seller_rfq_providers.dart';
import '../providers/seller_providers.dart' show SellerViewStatus;
import 'widgets/quote_form_sheet.dart';

/// Seller view of a single RFQ, with their quote (create / edit / delete).
class SellerRfqDetailPage extends ConsumerStatefulWidget {
  const SellerRfqDetailPage({super.key, required this.rfqId});

  final String rfqId;

  @override
  ConsumerState<SellerRfqDetailPage> createState() =>
      _SellerRfqDetailPageState();
}

class _SellerRfqDetailPageState extends ConsumerState<SellerRfqDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(sellerRfqDetailProvider(widget.rfqId).notifier).load();

  Future<void> _delete() async {
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete quote?',
      message: 'This removes your quote from the buyer\'s request.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (confirmed != true || !mounted) return;
    final error = await ref
        .read(sellerRfqDetailProvider(widget.rfqId).notifier)
        .deleteQuote();
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(context, 'Quote deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerRfqDetailProvider(widget.rfqId));
    final view = state.data;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Request', showBackButton: true),
      body: switch (state.status) {
        SellerViewStatus.initial || SellerViewStatus.loading
            when view == null =>
          const Center(child: LoadingIndicator()),
        SellerViewStatus.failure when view == null => ErrorStateWidget(
          message: state.message ?? 'Could not load this request.',
          onRetry: _load,
        ),
        _ =>
          view == null
              ? const Center(child: LoadingIndicator())
              : _Body(
                  view: view,
                  onQuote: () => QuoteFormSheet.show(
                    context,
                    rfqId: widget.rfqId,
                    initial: view.myQuote,
                  ),
                  onDelete: _delete,
                ),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.view,
    required this.onQuote,
    required this.onDelete,
  });

  final SellerRfqView view;
  final VoidCallback onQuote;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Rfq rfq = view.rfq;
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
        const SizedBox(height: AppSpacing.lg),
        Text('Your quote', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (view.myQuote == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'You haven\'t quoted this request yet.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else ...[
          QuoteTile(quote: view.myQuote!),
          const LuxuryDivider(),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: view.hasQuote ? 'Edit quote' : 'Send a quote',
            onPressed: onQuote,
          ),
        ),
        if (view.hasQuote) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: LuxuryOutlinedButton(
              label: 'Delete quote',
              onPressed: onDelete,
            ),
          ),
        ],
      ],
    );
  }
}
