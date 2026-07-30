import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';
import '../animations/pressable_scale.dart';

/// Circular luxury icon button with loading and disabled states.
class LuxuryIconButton extends StatelessWidget {
  const LuxuryIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isLoading = false,
    this.size = 44,
    this.backgroundColor = AppColors.pureWhite,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isLoading;
  final double size;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    return PressableScale(
      enabled: !disabled,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: disabled ? AppColors.softGrey : backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.softGrey),
            boxShadow: AppShadows.soft,
          ),
          child: IconButton(
            tooltip: tooltip,
            onPressed: disabled ? null : onPressed,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }
}
