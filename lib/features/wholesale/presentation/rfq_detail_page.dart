import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../domain/entities/rfq.dart';
import '../domain/entities/rfq_detail.dart';
import '../domain/entities/rfq_status.dart';
import '../providers/rfq_providers.dart';
import 'widgets/quote_tile.dart';

/// Read-only detail for a single RFQ: the request summary plus the quotes
/// received. The buyer may cancel while the request is still active; quotes are
/// display-only (no accept/reject — the schema has no accepted-quote linkage).
class RfqDetailPage extends ConsumerStatefulWidget {
  const RfqDetailPage({super.key, required this.rfqId});

  final String rfqId;

  @override
  ConsumerState<RfqDetailPage> createState() => _RfqDetailPageState();
}

class _RfqDetailPageState extends ConsumerState<RfqDetailPage> {
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(rfqDetailProvider(widget.rfqId).notifier).load();

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
  });

  final RfqDetail detail;
  final bool cancelling;
  final VoidCallback onCancel;

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
            QuoteTile(quote: quote),
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
