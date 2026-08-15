import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../providers/admin_providers.dart';

/// Admin console home. The whole surface is gated on [isAdminProvider]; a
/// non-admin who reaches the route sees an unauthorized state rather than any
/// moderation tools.
class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Admin', showBackButton: true),
      body: isAdmin.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not verify your access.',
          onRetry: () => ref.invalidate(isAdminProvider),
        ),
        data: (admin) => admin
            ? const _AdminMenu()
            : const EmptyStateWidget(
                title: 'Not authorized',
                message: 'This area is for administrators only.',
                icon: Icons.lock_outline,
              ),
      ),
    );
  }
}

class _AdminMenu extends StatelessWidget {
  const _AdminMenu();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        LuxuryCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: const Text('Seller verifications'),
            subtitle: const Text('Review stores awaiting verification'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.adminVerifications),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LuxuryCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Product moderation'),
            subtitle: const Text('Approve or reject submitted products'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.adminProducts),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LuxuryCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Catalog management'),
            subtitle: const Text('Categories, brands & attributes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.adminCatalog),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LuxuryCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.confirmation_number_outlined),
            title: const Text('Coupons'),
            subtitle: const Text('Create & manage discount coupons'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.adminCoupons),
          ),
        ),
      ],
    );
  }
}
