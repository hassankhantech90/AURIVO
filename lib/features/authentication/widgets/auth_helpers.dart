import 'package:flutter/material.dart';

import '../../../shared/design_system.dart';

/// Divider with centered text for alternate authentication actions.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'or'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: LuxuryDivider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: LuxuryDivider()),
      ],
    );
  }
}

/// Disabled social sign-in placeholder styled consistently with auth buttons.
class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LuxuryOutlinedButton(
      label: label,
      icon: Icons.g_mobiledata,
      onPressed: null,
    );
  }
}
