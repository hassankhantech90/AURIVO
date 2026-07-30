import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Typography scale using elegant serif headings and modern sans body text.
class AppTypography {
  const AppTypography._();

  static TextStyle get brand => GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.jetBlack,
  );

  static TextStyle get button => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.jetBlack,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.mediumGrey,
  );

  static TextTheme lightTextTheme() {
    final heading = GoogleFonts.playfairDisplayTextTheme();
    final body = GoogleFonts.interTextTheme();

    return body.copyWith(
      displayLarge: heading.displayLarge?.copyWith(
        color: AppColors.jetBlack,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: heading.displayMedium?.copyWith(
        color: AppColors.jetBlack,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: heading.displaySmall?.copyWith(
        color: AppColors.jetBlack,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: heading.headlineLarge?.copyWith(
        color: AppColors.jetBlack,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: heading.headlineMedium?.copyWith(
        color: AppColors.jetBlack,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: heading.headlineSmall?.copyWith(
        color: AppColors.jetBlack,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: heading.titleLarge?.copyWith(
        color: AppColors.jetBlack,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: body.titleMedium?.copyWith(
        color: AppColors.jetBlack,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: AppColors.charcoal,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.charcoal),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.charcoal),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.mediumGrey),
      labelLarge: button,
      labelMedium: body.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      labelSmall: body.labelSmall?.copyWith(color: AppColors.mediumGrey),
    );
  }

  static TextTheme darkTextTheme() {
    return lightTextTheme().apply(
      bodyColor: AppColors.pureWhite,
      displayColor: AppColors.pureWhite,
    );
  }
}
