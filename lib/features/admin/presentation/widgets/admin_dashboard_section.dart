import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../shared/design_system.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../providers/admin_dashboard_providers.dart';

/// Marketplace health at the top of the admin console (Requirements Doc §6
/// dashboard): GMV, order outcomes, active sellers, refunds/disputes/returns,
/// moderation queues and a 14-day GMV trend.
class AdminDashboardSection extends ConsumerStatefulWidget {
  const AdminDashboardSection({super.key});

  @override
  ConsumerState<AdminDashboardSection> createState() =>
      _AdminDashboardSectionState();
}

class _AdminDashboardSectionState extends ConsumerState<AdminDashboardSection> {
  static const _windows = <int?, String>{7: '7 days', 30: '30 days', null: 'All time'};
  int? _days = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(adminDashboardStatsProvider(_days));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Dashboard', style: theme.textTheme.titleLarge),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(adminDashboardStatsProvider(_days)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final entry in _windows.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _days == entry.key,
                onSelected: (_) => setState(() => _days = entry.key),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: LoadingIndicator()),
          ),
          error: (_, _) => ErrorStateWidget(
            message: 'Could not load the dashboard.',
            onRetry: () => ref.invalidate(adminDashboardStatsProvider(_days)),
          ),
          data: (s) => _Figures(stats: s),
        ),
      ],
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final tiles = <(String, String)>[
      ('GMV', formatMoney(s.gmv, currency: 'PKR')),
      ('Orders', '${s.orders}'),
      ('Completed', '${s.completedOrders}'),
      ('Paid', '${s.paidOrders}'),
      ('Awaiting fulfilment', '${s.pendingFulfilment}'),
      ('Avg. order', formatMoney(s.averageOrderValue, currency: 'PKR')),
      ('Cancelled', '${s.cancelledOrders}'),
      ('Refunded', '${s.refundedOrders}'),
      ('Active sellers', '${s.activeSellers}'),
      ('Open disputes', '${s.openDisputes}'),
      ('Open returns', '${s.openReturns}'),
      ('Moderation queue', '${s.moderationQueue}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 600 ? 4 : 2;
            final width =
                (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (label, value) in tiles)
                  SizedBox(
                    width: width,
                    child: _StatTile(label: label, value: value),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _GmvTrend(points: s.dailyGmv),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Payout liability appears once seller payouts are connected to a '
          'payment provider.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: theme.textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

/// 14-day GMV bars (no chart dependency).
class _GmvTrend extends StatelessWidget {
  const _GmvTrend({required this.points});

  final List<(DateTime, double)> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final peak = points.map((p) => p.$2).fold<double>(0, (a, b) => b > a ? b : a);
    return LuxuryCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GMV — last 14 days', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (day, gmv) in points)
                  Expanded(
                    child: Tooltip(
                      message: '${day.day}/${day.month}: ${formatMoney(gmv, currency: 'PKR')}',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: peak == 0 ? 2 : 2 + 78 * (gmv / peak),
                        decoration: BoxDecoration(
                          color: gmv == 0
                              ? AppColors.softGrey
                              : AppColors.primaryGold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
