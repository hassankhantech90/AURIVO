import 'package:flutter/material.dart';

import 'borders.dart';
import 'colors.dart';
import 'radius.dart';
import 'spacing.dart';
import 'typography.dart';

/// Material 3 theme configuration for the Pareezay.Hub luxury visual language.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGold,
      brightness: Brightness.light,
      primary: AppColors.primaryGold,
      onPrimary: AppColors.jetBlack,
      surface: AppColors.pureWhite,
      onSurface: AppColors.jetBlack,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.creamBackground,
      textTheme: AppTypography.lightTextTheme(),
      dividerTheme: const DividerThemeData(
        color: AppColors.softGrey,
        thickness: 1,
        space: AppSpacing.lg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.creamBackground,
        foregroundColor: AppColors.jetBlack,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.pureWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: AppBorders.rounded(AppRadius.xl),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.porcelain,
        selectedColor: AppColors.primaryGold.withValues(alpha: 0.18),
        side: AppBorders.subtle,
        shape: AppBorders.rounded(AppRadius.pill),
        labelStyle: AppTypography.caption.copyWith(color: AppColors.charcoal),
      ),
      inputDecorationTheme: _inputDecorationTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(style: _elevatedButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle),
      textButtonTheme: TextButtonThemeData(style: _textButtonStyle),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.jetBlack),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.pureWhite,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.softGrey,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.pureWhite,
        surfaceTintColor: Colors.transparent,
        shape: AppBorders.rounded(AppRadius.xxl),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: AppBorders.rounded(AppRadius.lg),
        backgroundColor: AppColors.jetBlack,
        contentTextStyle: AppTypography.lightTextTheme().bodyMedium?.copyWith(
          color: AppColors.pureWhite,
        ),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGold,
      brightness: Brightness.dark,
      primary: AppColors.primaryGold,
      onPrimary: AppColors.jetBlack,
      surface: AppColors.jetBlack,
      onSurface: AppColors.pureWhite,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.obsidian,
      textTheme: AppTypography.darkTextTheme(),
      inputDecorationTheme: _inputDecorationTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(style: _elevatedButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle),
      textButtonTheme: TextButtonThemeData(style: _textButtonStyle),
    );
  }

  static ButtonStyle get _elevatedButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryGold,
      foregroundColor: AppColors.jetBlack,
      disabledBackgroundColor: AppColors.softGrey,
      disabledForegroundColor: AppColors.mediumGrey,
      minimumSize: const Size.fromHeight(52),
      elevation: 0,
      textStyle: AppTypography.button,
      shape: AppBorders.rounded(AppRadius.lg),
    );
  }

  static ButtonStyle get _outlinedButtonStyle {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.jetBlack,
      disabledForegroundColor: AppColors.mediumGrey,
      minimumSize: const Size.fromHeight(52),
      side: AppBorders.gold,
      textStyle: AppTypography.button,
      shape: AppBorders.rounded(AppRadius.lg),
    );
  }

  static ButtonStyle get _textButtonStyle {
    return TextButton.styleFrom(
      foregroundColor: AppColors.deepGold,
      disabledForegroundColor: AppColors.mediumGrey,
      textStyle: AppTypography.button,
      shape: AppBorders.rounded(AppRadius.md),
    );
  }

  static InputDecorationTheme get _inputDecorationTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.pureWhite,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: AppBorders.input(),
      enabledBorder: AppBorders.input(),
      focusedBorder: AppBorders.input(
        side: const BorderSide(color: AppColors.primaryGold, width: 1.4),
      ),
      errorBorder: AppBorders.input(side: AppBorders.error),
      focusedErrorBorder: AppBorders.input(side: AppBorders.error),
      hintStyle: AppTypography.lightTextTheme().bodyMedium?.copyWith(
        color: AppColors.mediumGrey,
      ),
      // The fill is always pureWhite, so labels need an on-light colour in both
      // themes (colour-only overrides keep the default sizes). Floating label
      // stays gold on focus / red on error — otherwise on-light charcoal.
      labelStyle: const TextStyle(color: AppColors.charcoal),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.error)) {
          return const TextStyle(color: AppColors.error);
        }
        if (states.contains(WidgetState.focused)) {
          return const TextStyle(color: AppColors.primaryGold);
        }
        return const TextStyle(color: AppColors.charcoal);
      }),
    );
  }
}
