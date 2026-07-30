import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme lightTextTheme() {
    final heading = GoogleFonts.playfairDisplayTextTheme();
    final body = GoogleFonts.interTextTheme();

    return body.copyWith(
      displayLarge: heading.displayLarge?.copyWith(color: AppColors.jetBlack),
      displayMedium: heading.displayMedium?.copyWith(color: AppColors.jetBlack),
      displaySmall: heading.displaySmall?.copyWith(color: AppColors.jetBlack),
      headlineLarge: heading.headlineLarge?.copyWith(color: AppColors.jetBlack),
      headlineMedium: heading.headlineMedium?.copyWith(
        color: AppColors.jetBlack,
      ),
      headlineSmall: heading.headlineSmall?.copyWith(color: AppColors.jetBlack),
      titleLarge: heading.titleLarge?.copyWith(color: AppColors.jetBlack),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.charcoal),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.charcoal),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.mediumGrey),
    );
  }

  static TextTheme darkTextTheme() {
    return lightTextTheme().apply(
      bodyColor: AppColors.pureWhite,
      displayColor: AppColors.pureWhite,
    );
  }
}
