import 'package:flutter/material.dart';

import '../../../shared/design_system.dart';

/// Animated success mark used after password reset completion.
class AuthSuccessMark extends StatelessWidget {
  const AuthSuccessMark({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaleIn(
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: AppColors.success,
          size: 48,
        ),
      ),
    );
  }
}
