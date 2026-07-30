import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';
import 'shimmer_placeholder.dart';

/// Rounded skeleton block used while content is loading.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.md,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ShimmerPlaceholder(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.mistGrey,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton placeholder for product-style cards.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 160, radius: AppRadius.lg),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(width: 140),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 90),
          ],
        ),
      ),
    );
  }
}
