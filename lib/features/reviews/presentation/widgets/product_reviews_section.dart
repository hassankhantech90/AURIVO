import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/design_system.dart';
import '../../../authentication/providers/session_provider.dart';
import '../../providers/review_providers.dart';
import 'review_form_sheet.dart';
import 'review_tile.dart';

/// Reviews block embedded in the product-detail screen: an average summary
/// (computed client-side from the loaded approved reviews), the approved list,
/// the author's own pending review, and a create/edit entry point. Guests are
/// directed to login when they try to write.
class ProductReviewsSection extends ConsumerStatefulWidget {
  const ProductReviewsSection({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductReviewsSection> createState() =>
      _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends ConsumerState<ProductReviewsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(productReviewsProvider(widget.productId).notifier).load();

  Future<void> _openForm() async {
    final view = ref.read(productReviewsProvider(widget.productId)).data;
    await ReviewFormSheet.show(
      context,
      productId: widget.productId,
      orderItemId: view?.eligibleOrderItemId,
      initialReview: view?.myReview,
    );
    // The form submits through productReviewsProvider, which reloads the
    // section on success, so no manual refresh is needed here.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(productReviewsProvider(widget.productId));
    final view = state.data;
    final isAuthenticated = ref.watch(sessionProvider).isAuthenticated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Reviews', style: theme.textTheme.titleMedium),
            const Spacer(),
            if (view != null && view.hasApproved)
              RatingWidget(
                rating: view.averageRating,
                reviewCount: view.reviewCount,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (state.isLoading && view == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: LoadingIndicator()),
          )
        else if (state.status == ReviewViewStatus.failure && view == null)
          _InlineError(
            message: state.message ?? 'Could not load reviews.',
            onRetry: _load,
          )
        else ...[
          _WriteAction(
            isAuthenticated: isAuthenticated,
            hasMyReview: view?.hasMyReview ?? false,
            canWrite: view?.canWrite ?? false,
            onWrite: _openForm,
            onSignIn: () => context.push(AppRoutes.login),
          ),
          if (view != null &&
              view.myReview != null &&
              !view.myReview!.isApproved) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Your review', style: theme.textTheme.titleSmall),
            ReviewTile(review: view.myReview!, isMine: true),
            const LuxuryDivider(),
          ],
          if (view == null || !view.hasApproved)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'No reviews yet. Be the first to review this piece.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final review in view.approved) ...[
              ReviewTile(
                review: review,
                isMine: review.id == view.myReview?.id,
              ),
              const LuxuryDivider(),
            ],
        ],
      ],
    );
  }
}

class _WriteAction extends StatelessWidget {
  const _WriteAction({
    required this.isAuthenticated,
    required this.hasMyReview,
    required this.canWrite,
    required this.onWrite,
    required this.onSignIn,
  });

  final bool isAuthenticated;
  final bool hasMyReview;
  final bool canWrite;
  final VoidCallback onWrite;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return SizedBox(
        width: double.infinity,
        child: LuxuryOutlinedButton(
          label: 'Sign in to write a review',
          onPressed: onSignIn,
        ),
      );
    }
    if (!canWrite) {
      return Text(
        'Reviews can be written once your order of this piece is delivered.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return SizedBox(
      width: double.infinity,
      child: LuxuryOutlinedButton(
        label: hasMyReview ? 'Edit your review' : 'Write a review',
        onPressed: onWrite,
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          LuxuryTextButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}
