import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../orders/presentation/order_formatting.dart';
import '../domain/entities/support_ticket.dart';
import '../providers/support_providers.dart';
import 'widgets/support_status_badge.dart';

/// Admin ticket detail: read the request, assign it to yourself, and change
/// its status.
class AdminSupportDetailPage extends ConsumerStatefulWidget {
  const AdminSupportDetailPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<AdminSupportDetailPage> createState() =>
      _AdminSupportDetailPageState();
}

class _AdminSupportDetailPageState
    extends ConsumerState<AdminSupportDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(ticketsProvider).tickets.isEmpty) {
        ref.read(ticketsProvider.notifier).load();
      }
    });
  }

  Future<void> _report(Future<String?> action, String done) async {
    final error = await action;
    if (!mounted) return;
    error != null
        ? LuxurySnackBars.error(context, error)
        : LuxurySnackBars.success(context, done);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ticketsProvider);
    final ticket = state.tickets
        .where((t) => t.id == widget.ticketId)
        .firstOrNull;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Ticket', showBackButton: true),
      body: switch (state.status) {
        SupportStatus.loading || SupportStatus.initial when ticket == null =>
          const Center(child: LoadingIndicator()),
        _ when ticket == null => const EmptyStateWidget(
          title: 'Ticket not found',
          message: 'It may have been removed.',
          icon: Icons.help_outline,
        ),
        _ => _body(context, ticket),
      },
    );
  }

  Widget _body(BuildContext context, SupportTicket ticket) {
    final theme = Theme.of(context);
    final notifier = ref.read(ticketsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(ticket.subject, style: theme.textTheme.titleLarge),
            ),
            SupportStatusBadge(status: ticket.status),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${SupportTicketMeta.label(ticket.category)} · '
          '${SupportTicketMeta.label(ticket.priority)} priority'
          '${ticket.createdAt != null ? ' · ${formatOrderDateTime(ticket.createdAt!)}' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        LuxuryCard(child: Text(ticket.description, style: theme.textTheme.bodyMedium)),
        const SizedBox(height: AppSpacing.lg),

        Text('Status', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final s in SupportTicketMeta.statuses)
              LuxuryChip(
                label: SupportTicketMeta.label(s),
                selected: ticket.status == s,
                onTap: ticket.status == s
                    ? null
                    : () => _report(
                        notifier.setStatus(ticket.id, s),
                        'Status updated.',
                      ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        SizedBox(
          width: double.infinity,
          child: LuxuryOutlinedButton(
            label: ticket.assignedTo == null ? 'Assign to me' : 'Reassign to me',
            onPressed: () =>
                _report(notifier.assignToMe(ticket.id), 'Assigned to you.'),
          ),
        ),
      ],
    );
  }
}
