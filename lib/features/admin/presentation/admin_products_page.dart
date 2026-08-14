import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../seller/domain/entities/seller_product.dart';
import '../providers/admin_providers.dart';

/// Admin product-moderation queue: products with `status = pending`, each
/// approvable (`approved`) or rejectable. Only admins can make these
/// transitions (enforced by the products moderation guard trigger).
class AdminProductsPage extends ConsumerStatefulWidget {
  const AdminProductsPage({super.key});

  @override
  ConsumerState<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends ConsumerState<AdminProductsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(pendingProductsProvider.notifier).load();

  Future<void> _decide(SellerProduct product, String status) async {
    if (status == 'rejected') {
      final ok = await LuxuryDialogs.showConfirmation(
        context: context,
        title: 'Reject product?',
        message: 'Reject "${product.title}"? The seller can revise and '
            'resubmit.',
        confirmLabel: 'Reject',
        cancelLabel: 'Keep',
      );
      if (ok != true || !mounted) return;
    }
    final error = await ref
        .read(pendingProductsProvider.notifier)
        .setStatus(product.id, status);
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(
        context,
        status == 'approved' ? 'Product approved.' : 'Product rejected.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pendingProductsProvider);
    final products = state.data;

    return Scaffold(
      appBar: const LuxuryAppBar(
        title: 'Product moderation',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          AdminStatus.initial || AdminStatus.loading when products.isEmpty =>
            const Center(child: LoadingIndicator()),
          AdminStatus.failure when products.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load the queue.',
                onRetry: _load,
              ),
            ],
          ),
          _ when products.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'Nothing to review',
                message: 'No products are awaiting moderation.',
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _ProductTile(
              product: products[index],
              onApprove: () => _decide(products[index], 'approved'),
              onReject: () => _decide(products[index], 'rejected'),
            ),
          ),
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onApprove,
    required this.onReject,
  });

  final SellerProduct product;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          PriceWidget(
            price: product.basePrice,
            originalPrice: product.comparePrice,
            currency: product.currency,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: LuxuryOutlinedButton(
                  label: 'Reject',
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(label: 'Approve', onPressed: onApprove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
