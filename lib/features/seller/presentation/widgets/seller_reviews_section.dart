import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/design_system.dart';
import '../../../authentication/providers/session_provider.dart';
import '../../domain/entities/seller_storefront.dart';
import '../../providers/seller_providers.dart';
import 'seller_review_form_sheet.dart';
import 'seller_review_tile.dart';

/// Seller-reviews block embedded in the storefront: the approved reviews, the
/// author's own (possibly pending) review, and a create/edit entry point.
/// Guests are directed to login when they try to write. It reads the already
/// loaded [sellerStorefrontProvider] state — writes flow through it, so the
/// storefront reloads on success.
class SellerReviewsSection extends ConsumerWidget {
  const SellerReviewsSection({
    super.key,
    required this.slug,
    required this.storefront,
  });

  final String slug;
  final SellerStorefront storefront;

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    await SellerReviewFormSheet.show(
      context,
      slug: slug,
      initialReview: storefront.myReview,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAuthenticated = ref.watch(sessionProvider).isAuthenticated;
    final myReview = storefront.myReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Seller reviews', style: theme.textTheme.titleMedium),
            const Spacer(),
            if (storefront.hasReviews)
              RatingWidget(
                rating: storefront.averageRating,
                reviewCount: storefront.reviewCount,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: LuxuryOutlinedButton(
            label: !isAuthenticated
                ? 'Sign in to write a review'
                : (storefront.hasMyReview
                      ? 'Edit your review'
                      : 'Write a review'),
            onPressed: !isAuthenticated
                ? () => context.push(AppRoutes.login)
                : () => _openForm(context, ref),
          ),
        ),
        if (myReview != null && !myReview.isApproved) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Your review', style: theme.textTheme.titleSmall),
          SellerReviewTile(review: myReview, isMine: true),
          const LuxuryDivider(),
        ],
        if (!storefront.hasReviews)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'No reviews yet. Be the first to review this seller.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final review in storefront.approvedReviews) ...[
            SellerReviewTile(review: review, isMine: review.id == myReview?.id),
            const LuxuryDivider(),
          ],
      ],
    );
  }
}
