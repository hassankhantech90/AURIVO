import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/admin_user.dart';
import '../providers/admin_providers.dart' show AdminStatus;
import '../providers/admin_user_providers.dart';

/// Admin user directory: every account with status and roles, searchable by
/// name or email. Tap through to manage status and roles.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() => ref.read(adminUsersProvider.notifier).load();

  List<AdminUser> _filter(List<AdminUser> users) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users.where((u) {
      final p = u.profile;
      return p.fullName.toLowerCase().contains(q) ||
          (p.email?.toLowerCase().contains(q) ?? false) ||
          (p.phone?.contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersProvider);
    final users = _filter(state.data);

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Users',
        showBackButton: true,
        searchController: _search,
        searchHint: 'Search name or email',
        onSearchChanged: (_) => setState(() {}),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          AdminStatus.initial ||
          AdminStatus.loading when state.data.isEmpty =>
            const Center(child: LoadingIndicator()),
          AdminStatus.failure when state.data.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load users.',
                onRetry: _load,
              ),
            ],
          ),
          _ when users.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No users found',
                message: 'Try a different search.',
                icon: Icons.people_outline,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _UserTile(
              user: users[index],
              onTap: () => context.push(
                AppRoutes.adminUserDetailPath(users[index].profile.id),
              ),
            ),
          ),
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final AdminUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = user.profile;
    return LuxuryCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (user.isDeleted)
                const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.xs),
                  child: LuxuryBadge(
                    label: 'Deleted',
                    backgroundColor: AppColors.softGrey,
                    foregroundColor: AppColors.charcoal,
                  ),
                ),
              _StatusBadge(status: p.status),
            ],
          ),
          if (p.email != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(p.email!, style: theme.textTheme.bodySmall),
          ],
          if (user.roles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              user.roleNames.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mediumGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppColors.success,
      'suspended' => AppColors.warning,
      'blocked' => AppColors.error,
      _ => AppColors.mediumGrey,
    };
    return LuxuryBadge(label: status, backgroundColor: color);
  }
}
