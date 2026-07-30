import 'package:flutter/material.dart';

import '../domain/entities/onboarding_slide.dart';

/// Static onboarding copy used by the reusable onboarding page view.
class OnboardingSlides {
  const OnboardingSlides._();

  static const items = [
    OnboardingSlide(
      title: 'Discover Timeless Jewellery',
      subtitle:
          'Explore verified gold, silver and artificial jewellery from trusted sellers across Pakistan.',
      icon: Icons.diamond_outlined,
    ),
    OnboardingSlide(
      title: 'Buy & Sell with Confidence',
      subtitle: 'Secure shopping, trusted sellers and transparent pricing.',
      icon: Icons.verified_user_outlined,
    ),
    OnboardingSlide(
      title: 'Wholesale Marketplace',
      subtitle: 'Business buyers unlock wholesale prices, MOQ and quotations.',
      icon: Icons.storefront_outlined,
    ),
    OnboardingSlide(
      title: 'Luxury Delivered',
      subtitle:
          'Track orders, manage wishlists and shop premium collections effortlessly.',
      icon: Icons.local_shipping_outlined,
    ),
  ];
}
