import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/design_system.dart';
import '../../../products/domain/entities/product.dart';

/// Marketing headlines cycled across hero slides (mockup: "Crafted to be
/// remembered"). Short enough to read as one or two lines over the image.
const List<String> _headlines = [
  'Crafted to be remembered',
  'Heritage in every detail',
  'Timeless, made for you',
];

/// A swipeable hero carousel for Home: rounded image cards with a headline and
/// a gold flourish over a light left scrim, plus page dots. Slides are built
/// from featured [products] that have an image; with none it falls back to a
/// single branded gradient slide. Tapping a product slide opens that product;
/// the fallback opens Explore.
class HomeHeroCarousel extends StatefulWidget {
  const HomeHeroCarousel({super.key, required this.products});

  final List<Product> products;

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_HeroSlide> get _slides {
    final withImages = widget.products
        .where((p) => (p.primaryImageUrl ?? '').isNotEmpty)
        .take(5)
        .toList();
    if (withImages.isEmpty) {
      return [_HeroSlide(headline: _headlines.first)];
    }
    return [
      for (var i = 0; i < withImages.length; i++)
        _HeroSlide(
          product: withImages[i],
          headline: _headlines[i % _headlines.length],
        ),
    ];
  }

  void _openSlide(_HeroSlide slide) {
    final product = slide.product;
    context.push(
      product == null ? AppRoutes.explore : AppRoutes.productPath(product.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) =>
                _HeroCard(slide: slides[i], onTap: () => _openSlide(slides[i])),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          _HeroDots(count: slides.length, index: _index),
        ],
      ],
    );
  }
}

class _HeroSlide {
  const _HeroSlide({this.product, required this.headline});

  final Product? product;
  final String headline;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.slide, required this.onTap});

  final _HeroSlide slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = slide.product;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (product != null)
              NetworkImageWidget(imageUrl: product.primaryImageUrl!)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.porcelain, Color(0xFFEBD9A9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            // Light left scrim keeps the dark headline readable over any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xF2F8F5EF), Color(0x00F8F5EF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 190,
                    child: Text(
                      slide.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _Flourish(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short gold line + sparkle + line, echoing the mockup's ornament.
class _Flourish extends StatelessWidget {
  const _Flourish();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 1.5,
          child: ColoredBox(color: AppColors.primaryGold),
        ),
        SizedBox(width: AppSpacing.sm),
        Icon(Icons.auto_awesome, size: 14, color: AppColors.primaryGold),
        SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 28,
          height: 1.5,
          child: ColoredBox(color: AppColors.primaryGold),
        ),
      ],
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppDurations.normal,
            curve: AppAnimations.standard,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? AppColors.deepGold : AppColors.softGrey,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
