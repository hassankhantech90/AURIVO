import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../wholesale/domain/entities/rfq.dart';
import '../../wholesale/domain/entities/rfq_status.dart';
import '../providers/seller_product_providers.dart'
    show mySellerProfileIdProvider;
import '../providers/seller_rfq_providers.dart';
import '../providers/seller_providers.dart' show SellerViewStatus;

/// Seller RFQ inbox — the requests matched to this seller (RLS only returns
/// RFQs whose `seller_profile_id` is the seller's). Gated on having a store.
class SellerRfqInboxPage extends ConsumerWidget {
  const SellerRfqInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(mySellerProfileIdProvider);
    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Quote requests', showBackButton: true),
      body: sellerAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load your seller store.',
          onRetry: () => ref.invalidate(mySellerProfileIdProvider),
        ),
        data: (sellerId) => sellerId == null
            ? const EmptyStateWidget(
                title: 'No seller store yet',
                message: 'Only sellers receive quote requests.',
                icon: Icons.request_quote_outlined,
              )
            : const _InboxView(),
      ),
    );
  }
}

class _InboxView extends ConsumerStatefulWidget {
  const _InboxView();

  @override
  ConsumerState<_InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<_InboxView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(sellerRfqInboxProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerRfqInboxProvider);
    final rfqs = state.data ?? const [];

    return RefreshIndicator(
      onRefresh: _load,
      child: switch (state.status) {
        SellerViewStatus.initial || SellerViewStatus.loading
            when state.data == null =>
          const Center(child: LoadingIndicator()),
        SellerViewStatus.failure when state.data == null => ListView(
          children: [
            const SizedBox(height: 80),
            ErrorStateWidget(
              message: state.message ?? 'Could not load quote requests.',
              onRetry: _load,
            ),
          ],
        ),
        _ =>
          rfqs.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyStateWidget(
                      title: 'No quote requests',
                      message:
                          'Requests buyers send to your store appear here.',
                      icon: Icons.request_quote_outlined,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: rfqs.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final rfq = rfqs[index];
                    return _InboxTile(
                      rfq: rfq,
                      onTap: () =>
                          context.push(AppRoutes.sellerRfqDetailPath(rfq.id)),
                    );
                  },
                ),
      },
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.rfq, required this.onTap});

  final Rfq rfq;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      onTap: onTap,
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
                        'Qty ${rfq.quantity}',
                        style: theme.textTheme.titleSmall,
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
                      : 'No target price',
                  style: theme.textTheme.bodySmall,
                ),
                if (rfq.message != null && rfq.message!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    rfq.message!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.softGrey),
        ],
      ),
    );
  }
}
