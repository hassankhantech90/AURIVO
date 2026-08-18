import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../orders/presentation/order_formatting.dart';
import '../domain/entities/support_ticket.dart';
import '../providers/support_providers.dart';
import 'widgets/support_status_badge.dart';

/// Admin support console: every ticket with a status filter; tap through to
/// assign and change status.
class AdminSupportPage extends ConsumerStatefulWidget {
  const AdminSupportPage({super.key});

  @override
  ConsumerState<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends ConsumerState<AdminSupportPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(ticketsProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ticketsProvider);
    final active = ref.watch(
      ticketsProvider.notifier.select((n) => n.statusFilter),
    );
    final tickets = state.tickets;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Support', showBackButton: true),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                _chip('All', active == null, null),
                for (final s in SupportTicketMeta.statuses)
                  _chip(SupportTicketMeta.label(s), active == s, s),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: switch (state.status) {
                SupportStatus.initial ||
                SupportStatus.loading when tickets.isEmpty =>
                  const Center(child: LoadingIndicator()),
                SupportStatus.failure when tickets.isEmpty => ListView(
                  children: [
                    const SizedBox(height: 80),
                    ErrorStateWidget(
                      message: state.message ?? 'Could not load tickets.',
                      onRetry: _load,
                    ),
                  ],
                ),
                _ when tickets.isEmpty => ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyStateWidget(
                      title: 'No tickets',
                      message: 'No tickets match this filter.',
                      icon: Icons.support_agent_outlined,
                    ),
                  ],
                ),
                _ => ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: tickets.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _AdminTicketTile(
                    ticket: tickets[index],
                    onTap: () => context.push(
                      AppRoutes.adminSupportDetailPath(tickets[index].id),
                    ),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, String? status) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.sm),
    child: Center(
      child: LuxuryChip(
        label: label,
        selected: selected,
        onTap: () => ref
            .read(ticketsProvider.notifier)
            .load(status: status, setFilter: true),
      ),
    ),
  );
}

class _AdminTicketTile extends StatelessWidget {
  const _AdminTicketTile({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      onTap: onTap,
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
            '${SupportTicketMeta.label(ticket.category)} · '
            '${SupportTicketMeta.label(ticket.priority)}'
            '${ticket.createdAt != null ? ' · ${formatOrderDate(ticket.createdAt!)}' : ''}'
            '${ticket.assignedTo != null ? ' · assigned' : ''}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
