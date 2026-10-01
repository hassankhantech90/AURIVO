import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../orders/presentation/order_formatting.dart';
import '../domain/entities/dispute.dart';
import '../providers/dispute_providers.dart';

/// Admin dispute centre: open and closed disputes, newest first. Each opens
/// the shared thread, where the admin adds internal notes and resolves.
class AdminDisputesPage extends ConsumerWidget {
  const AdminDisputesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dispute centre'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Open'),
              Tab(text: 'Resolved'),
              Tab(text: 'Withdrawn'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DisputeList(status: Dispute.open),
            _DisputeList(status: Dispute.resolved),
            _DisputeList(status: Dispute.withdrawn),
          ],
        ),
      ),
    );
  }
}

class _DisputeList extends ConsumerWidget {
  const _DisputeList({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDisputesProvider(status));
    return async.when(
      loading: () => const Center(child: LoadingIndicator()),
      error: (e, _) => ErrorStateWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(adminDisputesProvider(status)),
      ),
      data: (disputes) => disputes.isEmpty
          ? const EmptyStateWidget(
              title: 'Nothing here',
              message: 'No disputes in this list.',
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(adminDisputesProvider(status).future),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: disputes.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final d = disputes[i];
                  return LuxuryCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: Text(d.reasonLabel),
                      subtitle: Text(
                        [
                          d.statusLabel,
                          if (d.createdAt != null)
                            'Opened ${formatOrderDate(d.createdAt!)}',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await context.push(AppRoutes.disputeDetailPath(d.id));
                        ref.invalidate(adminDisputesProvider(status));
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
