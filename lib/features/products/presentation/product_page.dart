import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../domain/entities/product.dart';
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
    ref.read(productDetailProvider.notifier).load(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productDetailProvider);
    return Scaffold(
      appBar: LuxuryAppBar(
        showBackButton: true,
        title: state.data?.product.title ?? 'Product',
      ),
      body: switch (state.status) {
        CatalogViewStatus.initial ||
        CatalogViewStatus.loading => const Center(child: LoadingIndicator()),
        CatalogViewStatus.failure => ErrorStateWidget(
          message: state.message ?? 'Could not load this product.',
          onRetry: _load,
        ),
        CatalogViewStatus.success => _ProductDetailView(detail: state.data!),
      },
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  const _ProductDetailView({required this.detail});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final Product product = detail.product;
    final imagePath = detail.primaryImage?.storagePath ?? '';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: NetworkImageWidget(
            imageUrl: imagePath,
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
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            LuxuryTag(label: product.jewelleryType),
            if (product.material != null) LuxuryTag(label: product.material!),
            if (product.purity != null) LuxuryTag(label: product.purity!),
          ],
        ),
        if (product.description != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Description', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            product.description!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (detail.variants.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Options', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ...detail.variants.map((variant) => _VariantRow(variant: variant)),
        ],
      ],
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.variant});

  final ProductVariant variant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            variant.weightGrams != null
                ? '${variant.weightGrams!.toStringAsFixed(2)} g'
                : 'Variant',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          PriceWidget(
            price: variant.price,
            originalPrice: variant.comparePrice,
            currency: variant.currency,
          ),
        ],
      ),
    );
  }
}
