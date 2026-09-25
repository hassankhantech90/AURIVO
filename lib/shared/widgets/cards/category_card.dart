import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';
import '../common/common.dart';
import 'luxury_card.dart';

/// Category card for jewellery collections and browse entry points.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.title,
    required this.imageUrl,
    this.onTap,
  });

  final String title;
  final String imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Image on top, title on a white footer below — matching the target
    // mockups. The image flexes to fill whatever height the cell leaves after
    // the label, so the card never overflows in a fixed-height rail.
    return LuxuryCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: NetworkImageWidget(
              imageUrl: imageUrl,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppColors.charcoal),
            ),
          ),
        ],
      ),
    );
  }
}
