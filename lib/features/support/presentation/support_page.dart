import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../../orders/presentation/order_formatting.dart';
import '../domain/entities/support_ticket.dart';
import '../providers/support_providers.dart';
import 'widgets/support_status_badge.dart';
import 'widgets/ticket_form_sheet.dart';

/// The user's support screen: their tickets and a form to raise a new one.
class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sessionProvider).isAuthenticated) _load();
    });
  }

  Future<void> _load() => ref.read(ticketsProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(
      sessionProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated) {
      return Scaffold(
        appBar: const LuxuryAppBar(title: 'Help & support', showBackButton: true),
        body: EmptyStateWidget(
          title: 'Sign in to contact support',
          message: 'Raise a ticket and track its status here.',
          icon: Icons.support_agent_outlined,
          action: PrimaryButton(
            label: 'Sign in',
            onPressed: () => context.push(AppRoutes.login),
          ),
        ),
      );
    }

    final state = ref.watch(ticketsProvider);
    final tickets = state.tickets;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TicketFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New ticket'),
      ),
      appBar: const LuxuryAppBar(title: 'Help & support', showBackButton: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          SupportStatus.initial ||
          SupportStatus.loading when tickets.isEmpty =>
            const Center(child: LoadingIndicator()),
          SupportStatus.failure when tickets.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load your tickets.',
                onRetry: _load,
              ),
            ],
          ),
          _ when tickets.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No tickets yet',
                message: 'Tap "New ticket" if you need help.',
                icon: Icons.support_agent_outlined,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _TicketTile(ticket: tickets[index]),
          ),
        },
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SupportStatusBadge(status: ticket.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ticket.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${SupportTicketMeta.label(ticket.category)}'
            '${ticket.createdAt != null ? ' · ${formatOrderDate(ticket.createdAt!)}' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }
}
