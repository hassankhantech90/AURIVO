import 'package:flutter/material.dart';

import '../../../shared/design_system.dart';
import '../domain/entities/onboarding_slide.dart';
import 'onboarding_illustration.dart';

/// Reusable content layout for a single onboarding page.
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({
    super.key,
    required this.slide,
    required this.isActive,
  });

  final OnboardingSlide slide;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return PageFade(
      visible: isActive,
      child: ScaleIn(
        visible: isActive,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 620;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FractionallySizedBox(
                        widthFactor: isCompact ? 0.72 : 0.88,
                        child: OnboardingIllustration(icon: slide.icon),
                      ),
                      SizedBox(
                        height: isCompact ? AppSpacing.lg : AppSpacing.xl,
                      ),
                      TweenAnimationBuilder<Offset>(
                        tween: Tween(
                          begin: const Offset(0, 0.08),
                          end: isActive ? Offset.zero : const Offset(0, 0.08),
                        ),
                        duration: AppDurations.slow,
                        curve: AppAnimations.standard,
                        builder: (context, offset, child) {
                          return Transform.translate(
                            offset: Offset(0, offset.dy * 120),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              slide.subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppColors.graphite,
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
