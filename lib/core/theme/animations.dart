import 'package:flutter/animation.dart';

/// Duration tokens for consistent motion timing.
class AppDurations {
  const AppDurations._();

  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration shimmer = Duration(milliseconds: 1400);
}

/// Curve tokens for refined luxury interactions.
class AppAnimations {
  const AppAnimations._();

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve gentle = Curves.easeInOut;
}
