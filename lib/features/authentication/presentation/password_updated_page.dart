import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../widgets/authentication_widgets.dart';

class PasswordUpdatedPage extends StatelessWidget {
  const PasswordUpdatedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Password Updated',
      subtitle:
          'Your password has been updated successfully. You can now sign in again.',
      showLogo: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AuthSuccessMark()),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Back to Login',
            icon: Icons.login,
            onPressed: () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
