import 'package:flutter/material.dart';

import '../../../shared/design_system.dart';

/// Decorative placeholder illustration for an onboarding slide.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: AppColors.softGrey),
          boxShadow: AppShadows.soft,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGold.withValues(alpha: 0.08),
              ),
            ),
            Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                boxShadow: AppShadows.goldGlow,
              ),
              child: Icon(icon, color: AppColors.pureWhite, size: 58),
            ),
          ],
        ),
      ),
    );
  }
}
