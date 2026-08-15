import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../domain/entities/admin_user.dart';
import '../domain/entities/app_role.dart';
import '../providers/admin_providers.dart' show AdminStatus;
import '../providers/admin_user_providers.dart';

/// Admin user detail: manage account status, soft-delete/restore, and roles.
/// A client guard prevents revoking your own or the last admin role; the
/// database trigger is the authoritative backstop.
class AdminUserDetailPage extends ConsumerStatefulWidget {
  const AdminUserDetailPage({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<AdminUserDetailPage> createState() =>
      _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends ConsumerState<AdminUserDetailPage> {
  static const _statuses = ['active', 'suspended', 'blocked'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(adminUsersProvider).data.isEmpty) {
        ref.read(adminUsersProvider.notifier).load();
      }
    });
  }

  Future<void> _report(Future<String?> action) async {
    final error = await action;
    if (!mounted) return;
    error != null
        ? LuxurySnackBars.error(context, error)
        : LuxurySnackBars.success(context, 'Updated.');
  }

  Future<void> _toggleRole(AdminUser user, AppRole role, bool has) async {
    final notifier = ref.read(adminUsersProvider.notifier);
    if (has && role.name == 'admin') {
      // Client guard — the DB trigger is the real backstop.
      final isSelf =
          ref.read(sessionProvider).user?.id == user.profile.userId;
      final adminCount = ref
          .read(adminUsersProvider)
          .data
          .where((u) => u.hasRole('admin') && !u.isDeleted)
          .length;
      if (isSelf) {
        LuxurySnackBars.error(context, "You can't remove your own admin role.");
        return;
      }
      if (adminCount <= 1) {
        LuxurySnackBars.error(context, 'At least one administrator is required.');
        return;
      }
    }
    await _report(
      has
          ? notifier.revokeRole(user.profile.id, role.id)
          : notifier.grantRole(user.profile.id, role.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersProvider);
    final user = state.data
        .where((u) => u.profile.id == widget.profileId)
        .firstOrNull;

    return Scaffold(
      appBar: LuxuryAppBar(
        title: user?.profile.fullName ?? 'User',
        showBackButton: true,
      ),
      body: switch (state.status) {
        AdminStatus.loading || AdminStatus.initial when user == null =>
          const Center(child: LoadingIndicator()),
        _ when user == null => const EmptyStateWidget(
          title: 'User not found',
          message: 'This account may have been removed.',
          icon: Icons.person_off_outlined,
        ),
        _ => _body(context, user),
      },
    );
  }

  Widget _body(BuildContext context, AdminUser user) {
    final theme = Theme.of(context);
    final rolesAsync = ref.watch(adminRolesProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(user.profile.fullName, style: theme.textTheme.titleLarge),
        if (user.profile.email != null)
          Text(user.profile.email!, style: theme.textTheme.bodySmall),
        if (user.profile.phone != null)
          Text(user.profile.phone!, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.lg),

        Text('Account status', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final s in _statuses)
              LuxuryChip(
                label: s,
                selected: user.profile.status == s,
                onTap: user.profile.status == s
                    ? null
                    : () => _report(
                        ref
                            .read(adminUsersProvider.notifier)
                            .setStatus(user.profile.id, s),
                      ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Text('Roles', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        rolesAsync.when(
          loading: () => const LoadingIndicator(),
          error: (_, _) => Text(
            'Could not load roles.',
            style: theme.textTheme.bodySmall,
          ),
          data: (roles) => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final role in roles)
                LuxuryChip(
                  label: role.name,
                  selected: user.hasRole(role.name),
                  onTap: () =>
                      _toggleRole(user, role, user.hasRole(role.name)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        SizedBox(
          width: double.infinity,
          child: LuxuryOutlinedButton(
            label: user.isDeleted ? 'Restore account' : 'Delete account',
            onPressed: () => _report(
              ref
                  .read(adminUsersProvider.notifier)
                  .setDeleted(user.profile.id, !user.isDeleted),
            ),
          ),
        ),
      ],
    );
  }
}
