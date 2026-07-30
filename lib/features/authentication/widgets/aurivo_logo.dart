import 'package:flutter/material.dart';

import '../../../shared/design_system.dart';

/// Centered AURIVO wordmark used on launch and onboarding surfaces.
class AurivoLogo extends StatelessWidget {
  const AurivoLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 64.0 : 88.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: AppShadows.goldGlow,
          ),
          child: Icon(
            Icons.diamond_outlined,
            color: AppColors.pureWhite,
            size: compact ? 30 : 42,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'AURIVO',
          style: AppTypography.brand.copyWith(
            fontSize: compact ? 28 : 38,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
