import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/validators/auth_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/authentication_widgets.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, _handleAuthState);
    final authState = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Create New Password',
      subtitle: 'Choose a strong password to protect your AURIVO account.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PasswordTextField(
              controller: _passwordController,
              labelText: 'New Password',
              validator: AuthValidators.password,
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordTextField(
              controller: _confirmPasswordController,
              labelText: 'Confirm Password',
              validator: (value) => AuthValidators.confirmPassword(
                value,
                _passwordController.text,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Update Password',
              icon: Icons.lock_reset,
              isLoading: authState.isLoading,
              onPressed: authState.isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authProvider.notifier)
        .resetPassword(_passwordController.text);
  }

  void _handleAuthState(AuthState? previous, AuthState next) {
    if (next.status == AuthStatus.success && next.message != null) {
      LuxurySnackBars.success(context, next.message!);
      context.go(AppRoutes.passwordUpdated);
      ref.read(authProvider.notifier).clearStatus();
    }

    if (next.status == AuthStatus.failure && next.message != null) {
      LuxurySnackBars.error(context, next.message!);
    }
  }
}
