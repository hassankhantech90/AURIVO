import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../providers/admin_providers.dart';
import 'widgets/admin_dashboard_section.dart';

/// Admin console home, gated on [staffAccessProvider]. Admins see every tool;
/// support and finance staff see only theirs (the server enforces the same
/// limits). Anyone else sees an unauthorized state.
class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(staffAccessProvider);
    return Scaffold(
      appBar: LuxuryAppBar(
        title:
            access.valueOrNull?.isAdmin == false &&
                (access.valueOrNull?.isStaff ?? false)
            ? 'Staff console'
            : 'Admin',
        showBackButton: true,
      ),
      body: access.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not verify your access.',
          onRetry: () {
            ref.invalidate(isAdminProvider);
            ref.invalidate(staffAccessProvider);
          },
        ),
        data: (a) => a.isStaff
            ? _AdminMenu(access: a)
            : const EmptyStateWidget(
                title: 'Not authorized',
                message: 'This area is for administrators only.',
                icon: Icons.lock_outline,
              ),
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry(
    this.icon,
    this.title,
    this.subtitle,
    this.route,
    this.allowed,
  );

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool Function(StaffAccess) allowed;
}

final _entries = <_MenuEntry>[
  _MenuEntry(
    Icons.verified_outlined,
    'Seller verifications',
    'Review stores awaiting verification',
    AppRoutes.adminVerifications,
    (a) => a.canModerate,
  ),
  _MenuEntry(
    Icons.business_center_outlined,
    'Business verifications',
    'Review B2B buyers awaiting verification',
    AppRoutes.adminBusinessVerifications,
    (a) => a.canModerate,
  ),
  _MenuEntry(
    Icons.gavel_outlined,
    'Dispute centre',
    'Review evidence, add notes, decide refunds',
    AppRoutes.adminDisputes,
    (a) => a.isStaff,
  ),
  _MenuEntry(
    Icons.receipt_long_outlined,
    'Orders',
    'Oversight, status, returns & refunds',
    AppRoutes.adminOrders,
    (a) => a.isStaff,
  ),
  _MenuEntry(
    Icons.support_agent_outlined,
    'Support',
    'Tickets, assignment & status',
    AppRoutes.adminSupport,
    (a) => a.canHandleTickets,
  ),
  _MenuEntry(
    Icons.history_edu_outlined,
    'Audit log',
    'Tamper-evident record of approvals & finance',
    AppRoutes.adminAudit,
    (a) => a.canReadAudit,
  ),
  _MenuEntry(
    Icons.article_outlined,
    'Content',
    'Home banners, FAQs and policy pages',
    AppRoutes.adminContent,
    (a) => a.canModerate,
  ),
  _MenuEntry(
    Icons.inventory_2_outlined,
    'Product moderation',
    'Approve or reject submitted products',
    AppRoutes.adminProducts,
    (a) => a.canModerate,
  ),
  _MenuEntry(
    Icons.category_outlined,
    'Catalog management',
    'Categories, brands & attributes',
    AppRoutes.adminCatalog,
    (a) => a.canModerate,
  ),
  _MenuEntry(
    Icons.confirmation_number_outlined,
    'Coupons',
    'Create & manage discount coupons',
    AppRoutes.adminCoupons,
    (a) => a.canModerate,
  ),
  _MenuEntry(
    Icons.manage_accounts_outlined,
    'Users & roles',
    'Accounts, status & role management',
    AppRoutes.adminUsers,
    (a) => a.canModerate,
  ),
];

class _AdminMenu extends StatelessWidget {
  const _AdminMenu({required this.access});

  final StaffAccess access;

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where((e) => e.allowed(access)).toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (access.canSeeDashboard) ...[
          const AdminDashboardSection(),
          const SizedBox(height: AppSpacing.xl),
        ],
        for (final e in visible) ...[
          LuxuryCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(e.icon),
              title: Text(e.title),
              subtitle: Text(e.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(e.route),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
