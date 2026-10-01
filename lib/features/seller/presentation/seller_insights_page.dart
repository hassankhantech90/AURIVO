import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/money.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/seller_insights.dart';
import '../providers/seller_insights_providers.dart';

/// Seller Studio insights (Requirements Doc §5): views, wishlist adds,
/// conversion, sales by period, top products and low-stock alerts.
class SellerInsightsPage extends ConsumerStatefulWidget {
  const SellerInsightsPage({super.key});

  @override
  ConsumerState<SellerInsightsPage> createState() => _SellerInsightsPageState();
}

class _SellerInsightsPageState extends ConsumerState<SellerInsightsPage> {
  static const _windows = <int?, String>{7: '7 days', 30: '30 days', null: 'All time'};
  int? _days = 30;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerInsightsProvider(_days));
    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Insights', showBackButton: true),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(sellerInsightsProvider(_days).future),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
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
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: LoadingIndicator()),
              ),
              error: (e, _) => ErrorStateWidget(
                message: 'Could not load your insights.',
                onRetry: () => ref.invalidate(sellerInsightsProvider(_days)),
              ),
              data: (i) => _Body(insights: i),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.insights});

  final SellerInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = insights;
    final tiles = <(String, String)>[
      ('Revenue', formatMoney(i.revenue, currency: 'PKR')),
      ('Orders', '${i.orders}'),
      ('Units sold', '${i.unitsSold}'),
      ('Product views', '${i.views}'),
      ('Wishlist adds', '${i.wishlistAdds}'),
      (
        'Conversion',
        i.hasMeaningfulConversion ? '${i.conversionPct!.toStringAsFixed(1)}%' : '—',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 600 ? 3 : 2;
            final w = (c.maxWidth - AppSpacing.sm * (cols - 1)) / cols;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (label, value) in tiles)
                  SizedBox(
                    width: w,
                    child: LuxuryCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: theme.textTheme.bodySmall),
                          const SizedBox(height: AppSpacing.xs),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(value, style: theme.textTheme.titleLarge),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (!i.hasMeaningfulConversion && i.orders > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Conversion appears once enough product views have been recorded.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _RevenueTrend(points: i.dailyRevenue),
        const SizedBox(height: AppSpacing.lg),
        Text('Low stock', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (i.lowStock.isEmpty)
          Text('All variants are above their stock threshold.',
              style: theme.textTheme.bodySmall)
        else
          for (final item in i.lowStock)
            LuxuryCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: item.available <= 0 ? AppColors.error : AppColors.warning,
                ),
                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    if (item.sku != null) 'SKU ${item.sku}',
                    item.available <= 0
                        ? 'Out of stock'
                        : '${item.available} left (alert at ${item.threshold})',
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  AppRoutes.sellerProductVariantsPath(item.productId),
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        Text('Top products', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (i.topProducts.isEmpty)
          Text('No sales in this period yet.', style: theme.textTheme.bodySmall)
        else
          for (final (rank, p) in i.topProducts.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${rank + 1}')),
              title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${p.units} sold'),
              trailing: Text(formatMoney(p.revenue, currency: 'PKR')),
            ),
      ],
    );
  }
}

class _RevenueTrend extends StatelessWidget {
  const _RevenueTrend({required this.points});

  final List<(DateTime, double)> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final peak = points.map((p) => p.$2).fold<double>(0, (a, b) => b > a ? b : a);
    return LuxuryCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales — last 14 days', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (day, revenue) in points)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${day.day}/${day.month}: ${formatMoney(revenue, currency: 'PKR')}',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: peak == 0 ? 2 : 2 + 78 * (revenue / peak),
                        decoration: BoxDecoration(
                          color: revenue == 0
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
