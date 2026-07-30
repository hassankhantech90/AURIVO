import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Scale transition helper for refined element entrances.
class ScaleIn extends StatelessWidget {
  const ScaleIn({
    super.key,
    required this.child,
    this.visible = true,
    this.duration = AppDurations.normal,
  });

  final Widget child;
  final bool visible;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0.96,
      duration: duration,
      curve: AppAnimations.standard,
      child: child,
    );
  }
}
