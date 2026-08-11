import 'package:flutter/material.dart';

import '../../../../shared/design_system.dart';
import '../../../reviews/domain/entities/review_status.dart';
import '../../domain/entities/seller_review.dart';

/// A single seller-review row. Reviewer identity is intentionally anonymous
/// (`profiles` are not readable cross-user), so verified purchasers show as
/// "Verified Buyer" and everyone else as an AURIVO customer. When [isMine] is
/// true and the review is not yet approved, a moderation-status chip is shown.
class SellerReviewTile extends StatelessWidget {
  const SellerReviewTile({
    super.key,
    required this.review,
    this.isMine = false,
  });

  final SellerReview review;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = review.verifiedPurchase
        ? 'Verified Buyer'
        : 'AURIVO Customer';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Stars(rating: review.rating),
              const SizedBox(width: AppSpacing.sm),
              if (review.verifiedPurchase)
                const LuxuryBadge(
                  label: 'Verified',
                  backgroundColor: AppColors.porcelain,
                  foregroundColor: AppColors.charcoal,
                ),
              const Spacer(),
              if (isMine && !review.isApproved)
                LuxuryBadge(
                  label: ReviewStatus.label(review.status),
                  backgroundColor: AppColors.softGrey,
                  foregroundColor: AppColors.charcoal,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(author, style: theme.textTheme.labelMedium),
              if (isMine) ...[
                const SizedBox(width: AppSpacing.xs),
                Text('(You)', style: theme.textTheme.bodySmall),
              ],
            ],
          ),
          if (review.title != null && review.title!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(review.title!, style: theme.textTheme.titleSmall),
          ],
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(review.comment!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: AppColors.primaryGold,
            size: 16,
          ),
      ],
    );
  }
}
