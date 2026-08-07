import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/validators/auth_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/authentication_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, _handleAuthState);
    final authState = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Sign in to continue your luxury jewellery journey.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _identifierController,
              labelText: 'Email / Phone',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.person_outline,
              validator: AuthValidators.emailOrPakistanPhone,
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordTextField(
              controller: _passwordController,
              labelText: 'Password',
              validator: AuthValidators.password,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Checkbox(
                  value: authState.rememberMe,
                  onChanged: authState.isLoading
                      ? null
                      : (value) => ref
                            .read(authProvider.notifier)
                            .setRememberMe(value ?? false),
                ),
                Expanded(
                  child: Text(
                    'Remember Me',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                LuxuryTextButton(
                  label: 'Forgot Password',
                  onPressed: authState.isLoading
                      ? null
                      : () => context.push(AppRoutes.forgotPassword),
                  size: AppButtonSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Login',
              icon: Icons.login,
              isLoading: authState.isLoading,
              onPressed: authState.isLoading ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            const AuthDivider(),
            const SizedBox(height: AppSpacing.lg),
            const AuthSocialButton(label: 'Continue with Google'),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'Continue as Guest',
              icon: Icons.person_outline,
              isLoading: authState.isLoading,
              onPressed: authState.isLoading ? null : _continueAsGuest,
            ),
            const SizedBox(height: AppSpacing.md),
            LuxuryTextButton(
              label: 'Create Account',
              onPressed: authState.isLoading
                  ? null
                  : () => context.push(AppRoutes.signup),
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
        .login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _continueAsGuest() async {
    await ref.read(authProvider.notifier).continueAsGuest();
  }

  void _handleAuthState(AuthState? previous, AuthState next) {
    if (next.status == AuthStatus.success && next.message != null) {
      LuxurySnackBars.success(context, next.message!);
      context.go(AppRoutes.home);
      ref.read(authProvider.notifier).clearStatus();
    }

    if (next.status == AuthStatus.failure && next.message != null) {
      LuxurySnackBars.error(context, next.message!);
    }
  }
}
