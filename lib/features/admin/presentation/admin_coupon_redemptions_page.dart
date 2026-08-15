import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../orders/presentation/order_formatting.dart';
import '../providers/admin_coupon_providers.dart';

/// Read-only admin oversight of a coupon's redemptions.
class AdminCouponRedemptionsPage extends ConsumerWidget {
  const AdminCouponRedemptionsPage({
    super.key,
    required this.couponId,
    this.couponCode,
  });

  final String couponId;
  final String? couponCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminCouponRedemptionsProvider(couponId));
    return Scaffold(
      appBar: LuxuryAppBar(
        title: couponCode == null ? 'Redemptions' : '${couponCode!} redemptions',
        showBackButton: true,
      ),
      body: async.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load redemptions.',
          onRetry: () =>
              ref.invalidate(adminCouponRedemptionsProvider(couponId)),
        ),
        data: (redemptions) {
          if (redemptions.isEmpty) {
            return const EmptyStateWidget(
              title: 'No redemptions yet',
              message: 'This coupon has not been used.',
              icon: Icons.receipt_long_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: redemptions.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final r = redemptions[index];
              return LuxuryCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    '${r.currency} ${r.discountAmount.toStringAsFixed(0)} off',
                  ),
                  subtitle: Text(
                    r.redeemedAt == null
                        ? 'Order ${r.orderId ?? '—'}'
                        : '${formatOrderDateTime(r.redeemedAt!)} · Order '
                              '${r.orderId ?? '—'}',
                  ),
                  leading: const Icon(Icons.local_offer_outlined),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
