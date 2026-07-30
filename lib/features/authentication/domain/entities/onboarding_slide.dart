import 'package:flutter/material.dart';

/// Immutable content model for a single onboarding page.
class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
