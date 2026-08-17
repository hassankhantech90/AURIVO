import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../../orders/presentation/order_formatting.dart';
import '../domain/entities/app_notification.dart';
import '../providers/notification_providers.dart';

/// The user's in-app notification centre: read, mark read, and dismiss. Rows are
/// created server-side; this screen is owner-scoped by RLS.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sessionProvider).isAuthenticated) _load();
    });
  }

  Future<void> _load() => ref.read(notificationsProvider.notifier).load();

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      await ref.read(notificationsProvider.notifier).markRead(n.id);
    }
    if (!mounted) return;
    final route = n.route;
    if (route != null) context.push(route);
  }

  Future<void> _markAll() async {
    final error = await ref.read(notificationsProvider.notifier).markAllRead();
    if (!mounted) return;
    if (error != null) LuxurySnackBars.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(
      sessionProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated) {
      return Scaffold(
        appBar: const LuxuryAppBar(title: 'Notifications', showBackButton: true),
        body: EmptyStateWidget(
          title: 'Sign in for notifications',
          message: 'Order updates and alerts appear here.',
          icon: Icons.notifications_none_outlined,
          action: PrimaryButton(
            label: 'Sign in',
            onPressed: () => context.push(AppRoutes.login),
          ),
        ),
      );
    }

    final state = ref.watch(notificationsProvider);
    final items = state.items;

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Notifications',
        showBackButton: true,
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: _markAll,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          NotificationStatus.initial ||
          NotificationStatus.loading when items.isEmpty =>
            const Center(child: LoadingIndicator()),
          NotificationStatus.failure when items.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load notifications.',
                onRetry: _load,
              ),
            ],
          ),
          _ when items.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No notifications',
                message: 'You are all caught up.',
                icon: Icons.notifications_none_outlined,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final n = items[index];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) =>
                    ref.read(notificationsProvider.notifier).remove(n.id),
                background: const ColoredBox(
                  color: AppColors.error,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: AppSpacing.lg),
                      child: Icon(Icons.delete_outline, color: AppColors.pureWhite),
                    ),
                  ),
                ),
                child: _NotificationTile(
                  notification: n,
                  onTap: () => _open(n),
                ),
              );
            },
          ),
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    return LuxuryCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Icon(
              unread ? Icons.circle : Icons.circle_outlined,
              size: 10,
              color: unread ? AppColors.primaryGold : AppColors.softGrey,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(notification.body, style: theme.textTheme.bodySmall),
                if (notification.createdAt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatOrderDateTime(notification.createdAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.mediumGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
