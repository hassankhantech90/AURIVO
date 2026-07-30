import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Fade transition helper for lightweight page and content reveals.
class PageFade extends StatelessWidget {
  const PageFade({
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
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: AppAnimations.standard,
      child: child,
    );
  }
}
