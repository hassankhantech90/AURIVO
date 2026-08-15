import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/admin_coupon.dart';
import '../providers/admin_coupon_providers.dart';
import '../providers/admin_providers.dart' show AdminStatus;
import 'widgets/coupon_form_sheet.dart';

/// Admin coupon manager: list all coupons with create / edit / status change /
/// soft-delete, and a link to each coupon's redemption oversight.
class AdminCouponsPage extends ConsumerStatefulWidget {
  const AdminCouponsPage({super.key});

  @override
  ConsumerState<AdminCouponsPage> createState() => _AdminCouponsPageState();
}

class _AdminCouponsPageState extends ConsumerState<AdminCouponsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(adminCouponsProvider.notifier).load();

  Future<void> _status(AdminCoupon c, String status, String done) async {
    final error = await ref
        .read(adminCouponsProvider.notifier)
        .setStatus(c.id, status);
    if (!mounted) return;
    error != null
        ? LuxurySnackBars.error(context, error)
        : LuxurySnackBars.success(context, done);
  }

  Future<void> _delete(AdminCoupon c) async {
    final ok = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Archive coupon?',
      message: 'Archive and hide "${c.code}".',
      confirmLabel: 'Archive',
      cancelLabel: 'Keep',
    );
    if (ok != true) return;
    final error = await ref.read(adminCouponsProvider.notifier).remove(c.id);
    if (!mounted) return;
    error != null
        ? LuxurySnackBars.error(context, error)
        : LuxurySnackBars.success(context, 'Coupon archived.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminCouponsProvider);
    final coupons = state.data;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CouponFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New coupon'),
      ),
      appBar: const LuxuryAppBar(title: 'Coupons', showBackButton: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          AdminStatus.initial || AdminStatus.loading when coupons.isEmpty =>
            const Center(child: LoadingIndicator()),
          AdminStatus.failure when coupons.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load coupons.',
                onRetry: _load,
              ),
            ],
          ),
          _ when coupons.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No coupons yet',
                message: 'Tap "New coupon" to create one.',
                icon: Icons.confirmation_number_outlined,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: coupons.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _CouponTile(coupon: coupons[index], parent: this),
          ),
        },
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({required this.coupon, required this.parent});

  final AdminCoupon coupon;
  final _AdminCouponsPageState parent;

  String get _discount => coupon.isPercentage
      ? '${coupon.discountValue.toStringAsFixed(0)}% off'
      : 'Rs ${coupon.discountValue.toStringAsFixed(0)} off';

  String get _usage => coupon.usageLimit == null
      ? '${coupon.usedCount} used'
      : '${coupon.usedCount}/${coupon.usageLimit} used';

  Color get _statusColor => switch (coupon.status) {
    'active' => AppColors.success,
    'paused' => AppColors.warning,
    'archived' || 'expired' => AppColors.softGrey,
    _ => AppColors.mediumGrey,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      onTap: () => CouponFormSheet.show(context, initial: coupon),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        coupon.code,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    LuxuryBadge(
                      label: coupon.status,
                      backgroundColor: _statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('$_discount · $_usage', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'edit' => CouponFormSheet.show(context, initial: coupon),
              'activate' =>
                parent._status(coupon, 'active', 'Coupon activated.'),
              'pause' => parent._status(coupon, 'paused', 'Coupon paused.'),
              'redemptions' => context.push(
                AppRoutes.adminCouponRedemptionsPath(coupon.id),
                extra: coupon.code,
              ),
              _ => parent._delete(coupon),
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (coupon.status != 'active')
                const PopupMenuItem(value: 'activate', child: Text('Activate')),
              if (coupon.status == 'active')
                const PopupMenuItem(value: 'pause', child: Text('Pause')),
              const PopupMenuItem(
                value: 'redemptions',
                child: Text('Redemptions'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Archive')),
            ],
          ),
        ],
      ),
    );
  }
}
