import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../profile/domain/entities/business_profile.dart';
import '../providers/admin_providers.dart';

/// Admin business-verification queue: B2B buyer profiles with
/// `verification_status = pending`, each approvable (`verified`) or rejectable.
/// Writes go through the admin RLS arm + the verification guard trigger.
class AdminBusinessVerificationsPage extends ConsumerStatefulWidget {
  const AdminBusinessVerificationsPage({super.key});

  @override
  ConsumerState<AdminBusinessVerificationsPage> createState() =>
      _AdminBusinessVerificationsPageState();
}

class _AdminBusinessVerificationsPageState
    extends ConsumerState<AdminBusinessVerificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(pendingBusinessesProvider.notifier).load();

  Future<void> _decide(BusinessProfile business, String status) async {
    if (status == 'rejected') {
      final ok = await LuxuryDialogs.showConfirmation(
        context: context,
        title: 'Reject business?',
        message:
            'Reject "${business.businessName}"? They can resubmit later.',
        confirmLabel: 'Reject',
        cancelLabel: 'Keep',
      );
      if (ok != true || !mounted) return;
    }
    final error = await ref
        .read(pendingBusinessesProvider.notifier)
        .setVerification(business.id, status);
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(
        context,
        status == 'verified' ? 'Business verified.' : 'Business rejected.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pendingBusinessesProvider);
    final businesses = state.data;

    return Scaffold(
      appBar: const LuxuryAppBar(
        title: 'Business verifications',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          AdminStatus.initial || AdminStatus.loading when businesses.isEmpty =>
            const Center(child: LoadingIndicator()),
          AdminStatus.failure when businesses.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load the queue.',
                onRetry: _load,
              ),
            ],
          ),
          _ when businesses.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'Nothing to review',
                message: 'No businesses are awaiting verification.',
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: businesses.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _BusinessTile(
              business: businesses[index],
              onApprove: () => _decide(businesses[index], 'verified'),
              onReject: () => _decide(businesses[index], 'rejected'),
            ),
          ),
        },
      ),
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({
    required this.business,
    required this.onApprove,
    required this.onReject,
  });

  final BusinessProfile business;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(business.businessName, style: theme.textTheme.titleSmall),
          if (business.businessType != null)
            Text(
              business.businessType!,
              style: theme.textTheme.bodySmall,
            ),
          Text(
            '${business.contactPerson} · ${business.contactPhone}',
            style: theme.textTheme.bodySmall,
          ),
          if (business.ntnNumber != null)
            Text('NTN ${business.ntnNumber}', style: theme.textTheme.bodySmall),
          if (business.strnNumber != null)
            Text(
              'STRN ${business.strnNumber}',
              style: theme.textTheme.bodySmall,
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
                child: PrimaryButton(label: 'Verify', onPressed: onApprove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
