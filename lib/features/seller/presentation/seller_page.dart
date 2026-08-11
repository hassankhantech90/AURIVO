import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../providers/seller_providers.dart';

/// Verified seller directory. Lists publicly visible (verified) storefronts;
/// tapping one opens its detail page by slug.
class SellerPage extends ConsumerStatefulWidget {
  const SellerPage({super.key});

  @override
  ConsumerState<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends ConsumerState<SellerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(verifiedSellersProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifiedSellersProvider);
    final sellers = state.data ?? const [];

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Sellers'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          SellerViewStatus.initial || SellerViewStatus.loading
              when state.data == null =>
            const Center(child: LoadingIndicator()),
          SellerViewStatus.failure when state.data == null => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load sellers.',
                onRetry: _load,
              ),
            ],
          ),
          _ =>
            sellers.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(
                        title: 'No sellers yet',
                        message: 'Verified storefronts will appear here.',
                        icon: Icons.storefront_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: sellers.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final seller = sellers[index];
                      return SellerCard(
                        name: seller.storeName,
                        imageUrl: seller.logoUrl,
                        subtitle: seller.city,
                        rating: seller.ratingCount > 0
                            ? seller.ratingAverage
                            : null,
                        isVerified: true,
                        onTap: () => context.push(
                          AppRoutes.sellerDetailPath(seller.slug),
                        ),
                      );
                    },
                  ),
        },
      ),
    );
  }
}
