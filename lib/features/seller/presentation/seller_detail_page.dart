import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../products/domain/entities/product.dart';
import '../../profile/domain/entities/seller_profile.dart';
import '../domain/entities/seller_storefront.dart';
import '../providers/seller_providers.dart';
import 'widgets/seller_reviews_section.dart';

/// Buyer-facing seller storefront: header, rating summary (client-computed from
/// loaded approved reviews), and the seller's approved products. Reviews are
/// rendered by the seller-reviews section (Slice B).
class SellerDetailPage extends ConsumerStatefulWidget {
  const SellerDetailPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<SellerDetailPage> createState() => _SellerDetailPageState();
}

class _SellerDetailPageState extends ConsumerState<SellerDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(sellerStorefrontProvider(widget.slug).notifier).load();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerStorefrontProvider(widget.slug));
    final storefront = state.data;

    return Scaffold(
      appBar: LuxuryAppBar(
        title: storefront?.seller.storeName ?? 'Store',
        showBackButton: true,
      ),
      body: switch (state.status) {
        SellerViewStatus.initial || SellerViewStatus.loading
            when storefront == null =>
          const Center(child: LoadingIndicator()),
        SellerViewStatus.failure when storefront == null => ErrorStateWidget(
          message: state.message ?? 'Could not load this store.',
          onRetry: _load,
        ),
        _ =>
          storefront == null
              ? const Center(child: LoadingIndicator())
              : _StorefrontBody(slug: widget.slug, storefront: storefront),
      },
    );
  }
}

class _StorefrontBody extends StatelessWidget {
  const _StorefrontBody({required this.slug, required this.storefront});

  final String slug;
  final SellerStorefront storefront;

  @override
  Widget build(BuildContext context) {
    final seller = storefront.seller;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeaderCard(seller: seller, storefront: storefront),
        const SizedBox(height: AppSpacing.lg),
        Text('Products', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (!storefront.hasProducts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'This store has no products yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: storefront.products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, index) {
              final Product product = storefront.products[index];
              return ProductCard(
                name: product.title,
                price: product.basePrice,
                originalPrice: product.comparePrice,
                currency: product.currency,
                imageUrl: '',
                rating: product.ratingCount > 0 ? product.ratingAverage : null,
                onTap: () => context.push(AppRoutes.productPath(product.id)),
              );
            },
          ),
        const SizedBox(height: AppSpacing.xl),
        SellerReviewsSection(slug: slug, storefront: storefront),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.seller, required this.storefront});

  final SellerProfile seller;
  final SellerStorefront storefront;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: NetworkImageWidget(imageUrl: seller.logoUrl ?? ''),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            seller.storeName,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const LuxuryBadge(
                          label: 'Verified',
                          backgroundColor: AppColors.porcelain,
                          foregroundColor: AppColors.charcoal,
                        ),
                      ],
                    ),
                    if (seller.city != null && seller.city!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(seller.city!, style: theme.textTheme.bodySmall),
                    ],
                    if (storefront.hasReviews) ...[
                      const SizedBox(height: AppSpacing.xs),
                      RatingWidget(
                        rating: storefront.averageRating,
                        reviewCount: storefront.reviewCount,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (seller.description != null && seller.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(seller.description!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
