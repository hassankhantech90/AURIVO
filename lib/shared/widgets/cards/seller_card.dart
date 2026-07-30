import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';
import '../common/common.dart';
import 'luxury_card.dart';

/// Seller summary card with avatar, rating, and verification affordance.
class SellerCard extends StatelessWidget {
  const SellerCard({
    super.key,
    required this.name,
    this.imageUrl,
    this.subtitle,
    this.rating,
    this.isVerified = false,
    this.onTap,
  });

  final String name;
  final String? imageUrl;
  final String? subtitle;
  final double? rating;
  final bool isVerified;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      onTap: onTap,
      child: Row(
        children: [
          LuxuryAvatar(
            imageUrl: imageUrl,
            initials: name.characters.firstOrNull,
            size: 56,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                if (rating != null) RatingWidget(rating: rating!),
              ],
            ),
          ),
          if (isVerified) const VerifiedBadge(),
        ],
      ),
    );
  }
}
