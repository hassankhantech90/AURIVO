import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../domain/entities/seller_variant.dart';
import '../providers/seller_variant_providers.dart';
import '../providers/seller_providers.dart' show SellerViewStatus;
import 'widgets/variant_form_sheet.dart';

/// Variant manager for a single seller product (SKU / price / stock).
class SellerVariantsPage extends ConsumerStatefulWidget {
  const SellerVariantsPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<SellerVariantsPage> createState() => _SellerVariantsPageState();
}

class _SellerVariantsPageState extends ConsumerState<SellerVariantsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(productVariantsProvider(widget.productId).notifier).load();

  Future<void> _delete(SellerVariant v) async {
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete variant?',
      message: 'This removes SKU "${v.sku}".',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (confirmed != true || !mounted) return;
    final error = await ref
        .read(productVariantsProvider(widget.productId).notifier)
        .remove(v.id);
    if (!mounted) return;
    if (error != null) LuxurySnackBars.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productVariantsProvider(widget.productId));
    final variants = state.data ?? const [];

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Variants', showBackButton: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            VariantFormSheet.show(context, productId: widget.productId),
        icon: const Icon(Icons.add),
        label: const Text('Add variant'),
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
                message: state.message ?? 'Could not load variants.',
                onRetry: _load,
              ),
            ],
          ),
          _ =>
            variants.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(
                        title: 'No variants yet',
                        message: 'Add a variant with its SKU, price and stock.',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: variants.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final v = variants[index];
                      return _VariantTile(
                        variant: v,
                        onEdit: () => VariantFormSheet.show(
                          context,
                          productId: widget.productId,
                          initial: v,
                        ),
                        onDelete: () => _delete(v),
                      );
                    },
                  ),
        },
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.variant,
    required this.onEdit,
    required this.onDelete,
  });

  final SellerVariant variant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      onTap: onEdit,
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
                        variant.sku,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (!variant.isActive)
                      const LuxuryBadge(
                        label: 'Inactive',
                        backgroundColor: AppColors.softGrey,
                        foregroundColor: AppColors.charcoal,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                PriceWidget(
                  price: variant.price,
                  originalPrice: variant.comparePrice,
                  currency: variant.currency,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Stock ${variant.stockQuantity} · Available '
                  '${variant.availableQuantity}',
                  style: theme.textTheme.bodySmall,
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
