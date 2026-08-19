import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../../orders/presentation/order_formatting.dart';
import '../domain/entities/conversation.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';

/// The user's conversations list. Rows are participant-scoped by RLS; unread is
/// derived from the caller's per-conversation read cursor.
class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sessionProvider).isAuthenticated) _load();
    });
  }

  Future<void> _load() => ref.read(conversationsProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(
      sessionProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated) {
      return Scaffold(
        appBar: const LuxuryAppBar(title: 'Messages', showBackButton: true),
        body: EmptyStateWidget(
          title: 'Sign in to view messages',
          message: 'Chat with sellers about your orders and quotes here.',
          icon: Icons.chat_bubble_outline,
          action: PrimaryButton(
            label: 'Sign in',
            onPressed: () => context.push(AppRoutes.login),
          ),
        ),
      );
    }

    final state = ref.watch(conversationsProvider);
    final items = state.items;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Messages', showBackButton: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          ChatStatus.initial ||
          ChatStatus.loading when items.isEmpty =>
            const Center(child: LoadingIndicator()),
          ChatStatus.failure when items.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load your messages.',
                onRetry: _load,
              ),
            ],
          ),
          _ when items.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No messages yet',
                message: 'Start a chat from a store, order, or quote request.',
                icon: Icons.chat_bubble_outline,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _ConversationTile(
              summary: items[index],
              onTap: () async {
                await context.push(
                  AppRoutes.messageThreadPath(items[index].conversation.id),
                );
                if (context.mounted) _load();
              },
            ),
          ),
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.summary, required this.onTap});

  final ConversationSummary summary;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conv = summary.conversation;
    final unread = summary.hasUnread;
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
                  conversationTitle(conv),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  conversationContextLabel(conv),
                  style: theme.textTheme.bodySmall,
                ),
                if (conv.lastMessageAt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatOrderDateTime(conv.lastMessageAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.mediumGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.softGrey),
        ],
      ),
    );
  }
}
