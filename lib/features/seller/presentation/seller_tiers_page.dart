import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../shared/design_system.dart';
import '../../products/domain/entities/price_tier.dart';
import '../providers/seller_providers.dart' show SellerViewStatus;
import '../providers/seller_tier_providers.dart';
import 'widgets/tier_form_sheet.dart';

/// Wholesale price-tier manager for a single seller product: "buy N+ at X each"
/// breaks that buyers see on the product page.
class SellerTiersPage extends ConsumerStatefulWidget {
  const SellerTiersPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<SellerTiersPage> createState() => _SellerTiersPageState();
}

class _SellerTiersPageState extends ConsumerState<SellerTiersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(productTiersProvider(widget.productId).notifier).load();

  Future<void> _add(List<PriceTier> existing) => TierFormSheet.show(
    context,
    productId: widget.productId,
    takenQuantities: existing.map((t) => t.minQuantity).toSet(),
  );

  Future<void> _delete(PriceTier tier) async {
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete tier?',
      message: 'This removes the ${tier.minQuantity}+ pieces price break.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (confirmed != true || !mounted) return;
    final error = await ref
        .read(productTiersProvider(widget.productId).notifier)
        .remove(tier.id);
    if (!mounted) return;
    if (error != null) LuxurySnackBars.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productTiersProvider(widget.productId));
    final tiers = state.data ?? const [];

    return Scaffold(
      appBar: const LuxuryAppBar(
        title: 'Wholesale pricing',
        showBackButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(tiers),
        icon: const Icon(Icons.add),
        label: const Text('Add tier'),
      ),
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
                message: state.message ?? 'Could not load your price tiers.',
                onRetry: _load,
              ),
            ],
          ),
          _ =>
            tiers.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(
                        title: 'No wholesale tiers yet',
                        message:
                            'Add a "buy N+ at X each" break to offer bulk '
                            'pricing.',
                        icon: Icons.local_offer_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: tiers.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final tier = tiers[index];
                      return _TierTile(
                        tier: tier,
                        onEdit: () => TierFormSheet.show(
                          context,
                          productId: widget.productId,
                          initial: tier,
                          takenQuantities: tiers
                              .map((t) => t.minQuantity)
                              .toSet(),
                        ),
                        onDelete: () => _delete(tier),
                      );
                    },
                  ),
        },
      ),
    );
  }
}

class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.tier,
    required this.onEdit,
    required this.onDelete,
  });

  final PriceTier tier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      onTap: onEdit,
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: AppColors.primaryGold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tier.minQuantity}+ pieces',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${formatMoney(tier.unitPrice, currency: 'PKR')} each',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
