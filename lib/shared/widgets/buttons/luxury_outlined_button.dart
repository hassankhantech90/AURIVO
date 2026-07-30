import 'package:flutter/material.dart';

import 'app_button.dart';

/// Outlined button for lower-emphasis actions with a gold border.
class LuxuryOutlinedButton extends StatelessWidget {
  const LuxuryOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = AppButtonSize.large,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      size: size,
      variant: AppButtonVariant.outlined,
    );
  }
}
