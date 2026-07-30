import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Luxury loading indicator using the gold design token.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: const CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.primaryGold,
        ),
      ),
    );
  }
}
