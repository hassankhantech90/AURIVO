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
    return LuxuryCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          AspectRatio(
            aspectRatio: 1.35,
            child: NetworkImageWidget(
              imageUrl: imageUrl,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                gradient: const LinearGradient(
                  colors: [Colors.transparent, Color(0x99000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.pureWhite),
            ),
          ),
        ],
      ),
    );
  }
}
