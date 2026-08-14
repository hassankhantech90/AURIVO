import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../profile/domain/entities/seller_profile.dart';
import '../providers/admin_providers.dart';

/// Admin seller-verification queue: stores with `verification_status = pending`,
/// each approvable (`verified`) or rejectable. Writes go through the admin RLS
/// arm + the verification guard trigger.
class AdminVerificationsPage extends ConsumerStatefulWidget {
  const AdminVerificationsPage({super.key});

  @override
  ConsumerState<AdminVerificationsPage> createState() =>
      _AdminVerificationsPageState();
}

class _AdminVerificationsPageState
    extends ConsumerState<AdminVerificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(pendingSellersProvider.notifier).load();

  Future<void> _decide(SellerProfile seller, String status) async {
    if (status == 'rejected') {
      final ok = await LuxuryDialogs.showConfirmation(
        context: context,
        title: 'Reject store?',
        message: 'Reject "${seller.storeName}"? The seller can resubmit later.',
        confirmLabel: 'Reject',
        cancelLabel: 'Keep',
      );
      if (ok != true || !mounted) return;
    }
    final error = await ref
        .read(pendingSellersProvider.notifier)
        .setVerification(seller.id, status);
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(
        context,
        status == 'verified' ? 'Store verified.' : 'Store rejected.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pendingSellersProvider);
    final sellers = state.data;

    return Scaffold(
      appBar: const LuxuryAppBar(
        title: 'Seller verifications',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          AdminStatus.initial || AdminStatus.loading when sellers.isEmpty =>
            const Center(child: LoadingIndicator()),
          AdminStatus.failure when sellers.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load the queue.',
                onRetry: _load,
              ),
            ],
          ),
          _ when sellers.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'Nothing to review',
                message: 'No stores are awaiting verification.',
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: sellers.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _SellerTile(
              seller: sellers[index],
              onApprove: () => _decide(sellers[index], 'verified'),
              onReject: () => _decide(sellers[index], 'rejected'),
            ),
          ),
        },
      ),
    );
  }
}

class _SellerTile extends StatelessWidget {
  const _SellerTile({
    required this.seller,
    required this.onApprove,
    required this.onReject,
  });

  final SellerProfile seller;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(seller.storeName, style: theme.textTheme.titleSmall),
          if (seller.city != null)
            Text(seller.city!, style: theme.textTheme.bodySmall),
          Text('/${seller.slug}', style: theme.textTheme.bodySmall),
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
                child: PrimaryButton(label: 'Verify', onPressed: onApprove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
