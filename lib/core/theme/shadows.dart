import 'package:flutter/material.dart';

import 'colors.dart';

/// Shadow tokens for soft premium elevation.
class AppShadows {
  const AppShadows._();

  static const soft = [
    BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const medium = [
    BoxShadow(color: Color(0x18000000), blurRadius: 28, offset: Offset(0, 14)),
  ];

  static const goldGlow = [
    BoxShadow(color: Color(0x33C9A227), blurRadius: 26, offset: Offset(0, 10)),
  ];

  static BoxShadow focusGlow = BoxShadow(
    color: AppColors.primaryGold.withValues(alpha: 0.18),
    blurRadius: 18,
    spreadRadius: 1,
  );
}
