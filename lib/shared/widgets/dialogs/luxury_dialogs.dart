import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';
import '../buttons/buttons.dart';
import '../loading/loading_indicator.dart';

/// Reusable dialog helpers for confirmation, success, error, and loading states.
class LuxuryDialogs {
  const LuxuryDialogs._();

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          LuxuryTextButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PrimaryButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
            size: AppButtonSize.medium,
          ),
        ],
      ),
    );
  }

  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return _showStatus(
      context: context,
      title: title,
      message: message,
      icon: Icons.error_outline,
      color: AppColors.error,
    );
  }

  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return _showStatus(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle_outline,
      color: AppColors.success,
    );
  }

  static Future<void> showLoading({
    required BuildContext context,
    String message = 'Please wait',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoadingIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  static Future<void> _showStatus({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon, color: color, size: 36),
        title: Text(title),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
            size: AppButtonSize.medium,
          ),
        ],
      ),
    );
  }
}
