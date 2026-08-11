import 'package:flutter/material.dart';

import '../../../../shared/design_system.dart';

/// Interactive 1–5 star selector for composing a review rating.
///
/// [value] is the current rating (0 means "not yet chosen"); [onChanged] fires
/// with the tapped star (1–5).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            constraints: const BoxConstraints(),
            tooltip: '$star star${star == 1 ? '' : 's'}',
            onPressed: () => onChanged(star),
            icon: Icon(
              star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: AppColors.primaryGold,
              size: size,
            ),
          ),
      ],
    );
  }
}
