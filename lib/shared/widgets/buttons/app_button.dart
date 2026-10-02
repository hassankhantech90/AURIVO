import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';
import '../animations/pressable_scale.dart';

/// Available sizes for reusable Pareezay.Hub buttons.
enum AppButtonSize { small, medium, large }

/// Shared luxury button foundation used by all Pareezay.Hub button variants.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = AppButtonSize.large,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonSize size;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final child = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
    );
    final disabled = onPressed == null || isLoading;
    final style = _styleFor(context);

    return PressableScale(
      enabled: !disabled,
      child: switch (variant) {
        AppButtonVariant.primary => ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: style,
          child: child,
        ),
        AppButtonVariant.secondary => ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: style,
          child: child,
        ),
        AppButtonVariant.outlined => OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: style,
          child: child,
        ),
        AppButtonVariant.text => TextButton(
          onPressed: disabled ? null : onPressed,
          style: style,
          child: child,
        ),
      },
    );
  }

  ButtonStyle _styleFor(BuildContext context) {
    final height = switch (size) {
      AppButtonSize.small => 40.0,
      AppButtonSize.medium => 46.0,
      AppButtonSize.large => 54.0,
    };
    final horizontal = switch (size) {
      AppButtonSize.small => AppSpacing.md,
      AppButtonSize.medium => AppSpacing.lg,
      AppButtonSize.large => AppSpacing.xl,
    };

    final shape = WidgetStatePropertyAll(AppBorders.rounded(AppRadius.lg));
    final padding = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: horizontal),
    );
    final minimumSize = WidgetStatePropertyAll(Size(0, height));

    return switch (variant) {
      AppButtonVariant.primary => ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGold,
        foregroundColor: AppColors.jetBlack,
        disabledBackgroundColor: AppColors.softGrey,
        disabledForegroundColor: AppColors.mediumGrey,
        elevation: 0,
        textStyle: AppTypography.button,
      ).copyWith(shape: shape, padding: padding, minimumSize: minimumSize),
      AppButtonVariant.secondary => ElevatedButton.styleFrom(
        backgroundColor: AppColors.jetBlack,
        foregroundColor: AppColors.pureWhite,
        disabledBackgroundColor: AppColors.softGrey,
        disabledForegroundColor: AppColors.mediumGrey,
        elevation: 0,
        textStyle: AppTypography.button,
      ).copyWith(shape: shape, padding: padding, minimumSize: minimumSize),
      AppButtonVariant.outlined => OutlinedButton.styleFrom(
        foregroundColor: AppColors.jetBlack,
        disabledForegroundColor: AppColors.mediumGrey,
        side: AppBorders.gold,
        textStyle: AppTypography.button,
      ).copyWith(shape: shape, padding: padding, minimumSize: minimumSize),
      AppButtonVariant.text => TextButton.styleFrom(
        foregroundColor: AppColors.deepGold,
        disabledForegroundColor: AppColors.mediumGrey,
        textStyle: AppTypography.button,
      ).copyWith(shape: shape, padding: padding, minimumSize: minimumSize),
    };
  }
}

/// Visual variants supported by [AppButton].
enum AppButtonVariant { primary, secondary, outlined, text }

/// Internal button content that keeps icon, label, and loading layout consistent.
class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (icon == null) {
      return Text(label);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    );
  }
}
