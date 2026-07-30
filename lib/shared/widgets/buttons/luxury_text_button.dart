import 'package:flutter/material.dart';

import 'app_button.dart';

/// Text-only button for subtle inline actions.
class LuxuryTextButton extends StatelessWidget {
  const LuxuryTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = AppButtonSize.medium,
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
      variant: AppButtonVariant.text,
    );
  }
}
