import 'package:flutter/material.dart';

import '../../../shared/design_system.dart';

/// Centered Pareezay.Hub wordmark used on launch, onboarding and auth
/// surfaces. Scales down to fit narrow screens.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: BrandWordmark(height: compact ? 26 : 34),
    );
  }
}
