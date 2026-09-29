import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/money.dart';
import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../../cart/providers/cart_providers.dart';
import '../../reviews/presentation/widgets/product_reviews_section.dart';
import '../../seller/providers/seller_providers.dart';
import '../../wholesale/presentation/wholesale_access.dart';
import '../../wholesale/presentation/widgets/rfq_form_sheet.dart';
import '../../wishlist/providers/wishlist_providers.dart';
import '../domain/entities/product.dart';
import '../domain/entities/price_tier.dart';
import '../domain/entities/product_detail.dart';
import '../domain/entities/product_variant.dart';
import '../providers/catalog_state.dart';
import '../providers/product_providers.dart';

/// Read-only product detail screen wired to [productDetailProvider].
class ProductPage extends ConsumerStatefulWidget {
  const ProductPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    ref.read(productDetailProvider(widget.productId).notifier).load();
    if (ref.read(sessionProvider).isAuthenticated) {
      ref.read(wishlistProvider.notifier).load();
    }
  }

  Future<void> _toggleFavourite() async {
    if (!ref.read(sessionProvider).isAuthenticated) {
      LuxurySnackBars.info(context, 'Sign in to save items to your wishlist.');
      context.push(AppRoutes.login);
      return;
    }
    await ref.read(wishlistProvider.notifier).toggle(widget.productId);
    if (!mounted) return;
    final state = ref.read(wishlistProvider);
    if (state.status == WishlistStatus.failure) {
      LuxurySnackBars.error(
        context,
        state.message ?? 'Could not update your wishlist.',
      );
    }
  }

  Future<void> _addToCart(String variantId) async {
    // Guests are routed to sign-in before any cart write, mirroring the
    // wishlist guard. The backend RLS remains authoritative; this is a clear
    // UX path instead of a generic authorization failure.
    if (!ref.read(sessionProvider).isAuthenticated) {
      LuxurySnackBars.info(context, 'Sign in to add items to your cart.');
      context.push(AppRoutes.login);
      return;
    }
    await ref.read(cartProvider.notifier).addItem(variantId);
    if (!mounted) return;
    final cartState = ref.read(cartProvider);
    if (cartState.status == CartStatus.failure) {
      LuxurySnackBars.error(
        context,
        cartState.message ?? 'Could not add to cart.',
      );
    } else {
      LuxurySnackBars.success(context, 'Added to cart');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productDetailProvider(widget.productId));
    final isFavourite = ref.watch(
      wishlistProvider.select((s) => s.contains(widget.productId)),
    );
    return Scaffold(
      appBar: LuxuryAppBar(
        showBackButton: true,
        title: state.data?.product.title ?? 'Product',
        actions: [
          IconButton(
            onPressed: _toggleFavourite,
            icon: Icon(
              isFavourite ? Icons.favorite : Icons.favorite_border,
              color: isFavourite ? AppColors.error : null,
            ),
            tooltip: isFavourite ? 'Remove from wishlist' : 'Add to wishlist',
          ),
        ],
      ),
      body: switch (state.status) {
        CatalogViewStatus.initial ||
        CatalogViewStatus.loading => const Center(child: LoadingIndicator()),
        CatalogViewStatus.failure => ErrorStateWidget(
          message: state.message ?? 'Could not load this product.',
          onRetry: _load,
        ),
        CatalogViewStatus.success => _ProductDetailView(
          detail: state.data!,
          onAddToCart: _addToCart,
        ),
      },
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  const _ProductDetailView({required this.detail, required this.onAddToCart});

  final ProductDetail detail;
  final void Function(String variantId) onAddToCart;

  @override
  Widget build(BuildContext context) {
    final Product product = detail.product;
    // Resolved public URL from the data layer; empty falls back to a placeholder.
    final imageUrl = product.primaryImageUrl ?? '';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: NetworkImageWidget(
            imageUrl: imageUrl,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(product.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        PriceWidget(
          price: product.basePrice,
          originalPrice: product.comparePrice,
          currency: product.currency,
        ),
        if (product.ratingCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          RatingWidget(
            rating: product.ratingAverage,
            reviewCount: product.ratingCount,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _SellerLink(sellerId: product.sellerId),
        const SizedBox(height: AppSpacing.sm),
        _Specifications(detail: detail),
        _WholesalePricing(product: product),
        if (product.description != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Description', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            product.description!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (detail.variants.length == 1) ...[
          // One variant: a single prominent Add to Cart (weight lives in specs).
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Add to Cart',
              icon: Icons.add_shopping_cart,
              onPressed: () => onAddToCart(detail.variants.first.id),
            ),
          ),
        ] else if (detail.variants.length > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Options', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ...detail.variants.map(
            (variant) => _VariantRow(
              variant: variant,
              onAdd: () => onAddToCart(variant.id),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _RequestQuoteButton(product: product),
        const SizedBox(height: AppSpacing.xl),
        ProductReviewsSection(productId: product.id),
      ],
    );
  }
}

/// Jewellery specification table (Type / Metal / Purity / Weight) built from the
/// fields that exist today. Certification, making charges and dimensions are
/// planned schema additions and will slot in as further rows.
class _Specifications extends StatelessWidget {
  const _Specifications({required this.detail});

  final ProductDetail detail;

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final product = detail.product;

    // Weight lives on variants; show the single value or a range across them.
    final weights = detail.variants
        .map((v) => v.weightGrams)
        .whereType<double>()
        .toList();
    String? weight;
    if (weights.isNotEmpty) {
      final lo = weights.reduce(math.min);
      final hi = weights.reduce(math.max);
      weight = lo == hi
          ? '${lo.toStringAsFixed(2)} g'
          : '${lo.toStringAsFixed(2)}–${hi.toStringAsFixed(2)} g';
    }

    final rows = <(IconData, String, String)>[
      (Icons.category_outlined, 'Type', _cap(product.jewelleryType)),
      if (product.material != null && product.material!.isNotEmpty)
        (Icons.diamond_outlined, 'Metal', _cap(product.material!)),
      if (product.purity != null && product.purity!.isNotEmpty)
        (Icons.workspace_premium_outlined, 'Purity', product.purity!.toUpperCase()),
      if (weight != null) (Icons.scale_outlined, 'Weight', weight),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Specifications', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        LuxuryCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const LuxuryDivider(height: 1),
                _SpecRow(
                  icon: rows[i].$1,
                  label: rows[i].$2,
                  value: rows[i].$3,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Wholesale block: minimum order quantity and any tiered "buy N+ at X each"
/// price breaks. Renders nothing when the product has neither. Tiers load
/// lazily via [productPriceTiersProvider]; MOQ comes from the product itself.
class _WholesalePricing extends ConsumerWidget {
  const _WholesalePricing({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moq = product.minOrderQuantity;
    final showMoq = moq != null && moq > 1;
    final tiers =
        ref.watch(productPriceTiersProvider(product.id)).valueOrNull ??
        const <PriceTier>[];

    final rows = <(IconData, String, String)>[
      if (showMoq)
        (Icons.inventory_2_outlined, 'Minimum order', '$moq pieces'),
      for (final tier in tiers)
        (
          Icons.local_offer_outlined,
          '${tier.minQuantity}+ pieces',
          '${formatMoney(tier.unitPrice, currency: product.currency)} each',
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text('Wholesale', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        LuxuryCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const LuxuryDivider(height: 1),
                _SpecRow(icon: rows[i].$1, label: rows[i].$2, value: rows[i].$3),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGold),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.mediumGrey,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Bound + end-align so a long value can't overflow at large text scales.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Request a Quote" CTA for wholesale/custom enquiries. Pre-fills the product
/// and seller context; guests are routed to login. The buyer identity is
/// resolved server-side on submit — never supplied by this screen.
class _RequestQuoteButton extends ConsumerWidget {
  const _RequestQuoteButton({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(sessionProvider).isAuthenticated;
    return SizedBox(
      width: double.infinity,
      child: LuxuryOutlinedButton(
        label: 'Request a Quote',
        onPressed: () async {
          if (!isAuthenticated) {
            context.push(AppRoutes.login);
            return;
          }
          if (!await ensureVerifiedBusiness(context, ref)) return;
          if (!context.mounted) return;
          RfqFormSheet.show(
            context,
            productId: product.id,
            sellerProfileId: product.sellerId,
            contextLabel: product.title,
          );
        },
      ),
    );
  }
}

/// Tappable "Sold by ..." store link, shown only when the product's seller is a
/// publicly visible (verified) storefront. Navigates to the seller detail page
/// by slug.
class _SellerLink extends ConsumerWidget {
  const _SellerLink({required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(sellerByIdProvider(sellerId));
    final seller = sellerAsync.valueOrNull;
    if (seller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push(AppRoutes.sellerDetailPath(seller.slug)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: AppColors.primaryGold,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Sold by ${seller.storeName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.softGrey),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.variant, required this.onAdd});

  final ProductVariant variant;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              variant.weightGrams != null
                  ? '${variant.weightGrams!.toStringAsFixed(2)} g'
                  : 'Variant',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          // Bound the price so its FittedBox(scaleDown) can shrink wide PKR
          // amounts (incl. a struck compare price) to fit on narrow phones and
          // large text scales, instead of overflowing the row.
          Flexible(
            child: PriceWidget(
              price: variant.price,
              originalPrice: variant.comparePrice,
              currency: variant.currency,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            onPressed: onAdd,
            icon: const Icon(Icons.add_shopping_cart),
            tooltip: 'Add to cart',
          ),
        ],
      ),
    );
  }
}
