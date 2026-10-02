import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../widgets/authentication_widgets.dart';

/// Password reset is not self-service yet: a link-based reset needs deep-linking
/// and a code-based reset needs custom SMTP (both deferred). For the pilot this
/// screen points the user to support (an operator resets the password from the
/// Supabase dashboard) rather than offering a flow that cannot complete.
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset Password',
      subtitle: 'Password reset is handled by our team during the pilot.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Icon(
              Icons.lock_reset_outlined,
              size: 64,
              color: AppColors.primaryGold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'To reset your password, please contact Pareezay.Hub support and we '
            'will help you regain access to your account.',
            textAlign: TextAlign.center,
            // Explicit on-light colour: inline Text built above the
            // AuthScaffold light theme, on the white card.
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.charcoal),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Back to sign in',
            icon: Icons.login,
            onPressed: () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
