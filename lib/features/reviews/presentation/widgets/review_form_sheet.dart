import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../domain/entities/product_review.dart';
import '../../providers/review_providers.dart';
import 'star_rating_input.dart';

/// Modal bottom-sheet form for creating or editing a product review.
///
/// Presented via [LuxuryBottomSheet]; there is no dedicated route. Returns
/// `true` through the sheet when a review was created, edited, or deleted so
/// the caller can refresh the relevant review state.
class ReviewFormSheet extends ConsumerStatefulWidget {
  const ReviewFormSheet({
    super.key,
    required this.productId,
    this.orderItemId,
    this.initialReview,
  });

  final String productId;
  final String? orderItemId;
  final ProductReview? initialReview;

  /// Shows the form and resolves to `true` when a change was saved.
  static Future<bool?> show(
    BuildContext context, {
    required String productId,
    String? orderItemId,
    ProductReview? initialReview,
  }) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => ReviewFormSheet(
        productId: productId,
        orderItemId: orderItemId,
        initialReview: initialReview,
      ),
    );
  }

  @override
  ConsumerState<ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends ConsumerState<ReviewFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _commentController;
  late int _rating;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.initialReview != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReview;
    _rating = initial?.rating ?? 0;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _commentController = TextEditingController(text: initial?.comment ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      setState(() => _error = 'Please choose a rating between 1 and 5.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final message = await ref
        .read(productReviewsProvider(widget.productId).notifier)
        .submit(
          reviewId: widget.initialReview?.id,
          orderItemId: widget.orderItemId,
          rating: _rating,
          title: _titleController.text,
          comment: _commentController.text,
        );

    if (!mounted) return;
    if (message == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = message;
      });
    }
  }

  Future<void> _delete() async {
    final review = widget.initialReview;
    if (review == null) return;
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete review?',
      message: 'This will permanently remove your review.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    final message = await ref
        .read(productReviewsProvider(widget.productId).notifier)
        .remove(review.id);

    if (!mounted) return;
    if (message == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _deleting = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _deleting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEditing ? 'Edit your review' : 'Write a review',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Your rating', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        StarRatingInput(
          value: _rating,
          onChanged: (value) => setState(() {
            _rating = value;
            _error = null;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _titleController,
          labelText: 'Title (optional)',
          hintText: 'Sum up your experience',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        MultilineTextField(
          controller: _commentController,
          labelText: 'Review (optional)',
          hintText: 'What did you like or dislike?',
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your review will be published after approval.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: LoadingButton(
            label: _isEditing ? 'Save changes' : 'Submit review',
            isLoading: _submitting,
            onPressed: busy ? null : _submit,
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: LuxuryOutlinedButton(
              label: 'Delete review',
              isLoading: _deleting,
              onPressed: busy ? null : _delete,
            ),
          ),
        ],
      ],
    );
  }
}
