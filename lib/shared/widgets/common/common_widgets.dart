import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Small status badge for compact labels and counters.
class LuxuryBadge extends StatelessWidget {
  const LuxuryBadge({
    super.key,
    required this.label,
    this.backgroundColor = AppColors.jetBlack,
    this.foregroundColor = AppColors.pureWhite,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: foregroundColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable-looking chip for filters and compact metadata.
class LuxuryChip extends StatelessWidget {
  const LuxuryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      backgroundColor: selected
          ? AppColors.primaryGold.withValues(alpha: 0.16)
          : AppColors.pureWhite,
      side: BorderSide(
        color: selected ? AppColors.primaryGold : AppColors.softGrey,
      ),
      shape: AppBorders.rounded(AppRadius.pill),
    );
  }
}

/// Compact tag pill for categories, materials, and product attributes.
class LuxuryTag extends StatelessWidget {
  const LuxuryTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LuxuryBadge(
      label: label,
      backgroundColor: AppColors.porcelain,
      foregroundColor: AppColors.charcoal,
    );
  }
}

/// Star rating display for products and sellers.
class RatingWidget extends StatelessWidget {
  const RatingWidget({
    super.key,
    required this.rating,
    this.reviewCount,
    this.size = 16,
  });

  final double rating;
  final int? reviewCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: AppColors.primaryGold, size: size),
        const SizedBox(width: AppSpacing.xs),
        Text(
          rating.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text('($reviewCount)', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// Subtle divider aligned with the soft luxury surface system.
class LuxuryDivider extends StatelessWidget {
  const LuxuryDivider({super.key, this.height = AppSpacing.lg});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Divider(height: height, color: AppColors.softGrey);
  }
}

/// Section title row with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

/// Price display with optional original price and currency label.
class PriceWidget extends StatelessWidget {
  const PriceWidget({
    super.key,
    required this.price,
    this.originalPrice,
    this.currency = 'USD',
  });

  final num price;
  final num? originalPrice;
  final String currency;

  @override
  Widget build(BuildContext context) {
    // Scale the whole price block down (never up) so wide amounts — e.g. large
    // PKR prices, optionally with a struck-through original — stay fully
    // readable on narrow product-card cells instead of overflowing. No digits
    // are ellipsised or dropped; on roomy layouts nothing changes.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$currency ${price.toStringAsFixed(2)}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.jetBlack),
          ),
          if (originalPrice != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$currency ${originalPrice!.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state with optional icon, message, and action.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.diamond_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.primaryGold),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with optional retry action.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'Something went wrong',
      message: message,
      icon: Icons.error_outline,
      action: onRetry == null
          ? null
          : OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}

/// Circular avatar for users, sellers, and support agents.
class LuxuryAvatar extends StatelessWidget {
  const LuxuryAvatar({super.key, this.imageUrl, this.initials, this.size = 48});

  final String? imageUrl;
  final String? initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.porcelain,
      foregroundColor: AppColors.jetBlack,
      backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
      child: imageUrl == null ? Text(initials ?? '') : null,
    );
  }
}

/// Verified seller badge with gold check mark styling.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.label = 'Verified'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LuxuryBadge(
      label: label,
      icon: Icons.verified_rounded,
      backgroundColor: AppColors.primaryGold.withValues(alpha: 0.18),
      foregroundColor: AppColors.deepGold,
    );
  }
}

/// Wholesale availability badge for B2B product and seller surfaces.
class WholesaleBadge extends StatelessWidget {
  const WholesaleBadge({super.key, this.label = 'Wholesale'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LuxuryBadge(
      label: label,
      icon: Icons.storefront_outlined,
      backgroundColor: AppColors.jetBlack,
      foregroundColor: AppColors.pureWhite,
    );
  }
}

/// Favourite toggle button for wishlisting products.
class FavouriteButton extends StatelessWidget {
  const FavouriteButton({
    super.key,
    required this.isFavourite,
    required this.onPressed,
  });

  final bool isFavourite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Saved state is a filled charcoal heart (the mockups' monochrome look);
    // the filled/outline switch carries the meaning, not colour.
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
      color: AppColors.jetBlack,
      style: IconButton.styleFrom(backgroundColor: AppColors.pureWhite),
    );
  }
}

/// Quantity selector with increment and decrement controls.
class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    this.min = 1,
  });

  final int value;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final int min;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.softGrey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value <= min ? null : onDecrement,
            icon: const Icon(Icons.remove),
          ),
          Text('$value', style: Theme.of(context).textTheme.titleSmall),
          IconButton(onPressed: onIncrement, icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}
