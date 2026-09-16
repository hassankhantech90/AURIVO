import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';
import '../common/common.dart';
import 'luxury_card.dart';

/// Reusable product card for catalogue, wishlist, and recommendation surfaces.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.currency = 'USD',
    this.originalPrice,
    this.rating,
    this.isFavourite = false,
    this.onTap,
    this.onFavouritePressed,
  });

  final String name;
  final num price;
  final String imageUrl;
  final String currency;
  final num? originalPrice;
  final double? rating;
  final bool isFavourite;
  final VoidCallback? onTap;
  final VoidCallback? onFavouritePressed;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The image flexes to fill the space left after the text block, so a
          // fixed grid cell never overflows on narrow phones. On typical cells
          // (childAspectRatio 0.62) this stays ~square; on tight cells it simply
          // shortens to keep title/price/rating fully visible.
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkImageWidget(
                  imageUrl: imageUrl,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: FavouriteButton(
                    isFavourite: isFavourite,
                    onPressed: onFavouritePressed,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                PriceWidget(
                  price: price,
                  originalPrice: originalPrice,
                  currency: currency,
                ),
                if (rating != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  RatingWidget(rating: rating!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
