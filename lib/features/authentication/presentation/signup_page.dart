import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/email_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/validators/auth_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/authentication_widgets.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, _handleAuthState);
    final authState = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Create Account',
      subtitle: 'Join Pareezay.Hub to buy, sell and discover refined jewellery.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _nameController,
              labelText: 'Full Name',
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.fullName,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              controller: _emailController,
              labelText: 'Email',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              controller: _phoneController,
              labelText: 'Phone',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.pakistanPhone,
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordTextField(
              controller: _passwordController,
              labelText: 'Password',
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
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: authState.acceptedTerms,
              onChanged: authState.isLoading
                  ? null
                  : (value) => ref
                        .read(authProvider.notifier)
                        .setAcceptedTerms(value ?? false),
              title: Text(
                'I accept the Terms & Conditions',
                // Explicit on-light colour: inline Text built above the
                // AuthScaffold light theme, on the white card.
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.charcoal),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Create Account',
              icon: Icons.person_add_alt,
              isLoading: authState.isLoading,
              onPressed: authState.isLoading || !authState.acceptedTerms
                  ? null
                  : _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            LuxuryTextButton(
              label: 'Already have an account',
              onPressed: authState.isLoading
                  ? null
                  : () => context.go(AppRoutes.login),
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
        .signup(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        );
  }

  void _handleAuthState(AuthState? previous, AuthState next) {
    if (next.status == AuthStatus.success && next.message != null) {
      LuxurySnackBars.success(context, next.message!);
      if (EmailConfig.otpCodes) {
        // Custom SMTP live: the email carries a 6-digit code.
        ref.read(authProvider.notifier).startOtpCountdown();
        context.go('${AppRoutes.otp}?flow=signup');
      } else {
        // Built-in mailer sends a confirmation link: "check your email",
        // then sign in once confirmed.
        context.go(AppRoutes.verifyEmail);
      }
      ref.read(authProvider.notifier).clearStatus();
    }

    if (next.status == AuthStatus.failure && next.message != null) {
      LuxurySnackBars.error(context, next.message!);
    }
  }
}
