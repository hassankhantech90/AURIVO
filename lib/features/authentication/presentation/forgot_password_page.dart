import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/email_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/validators/auth_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/authentication_widgets.dart';

/// Password reset. With email codes enabled ([EmailConfig.otpCodes], i.e.
/// custom SMTP + the `{{ .Token }}` recovery template are live) the user
/// requests a 6-digit code and continues on the OTP screen. Without them a
/// code can't be delivered, so the screen points to support instead of
/// offering a flow that cannot complete.
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key, this.useCodes = EmailConfig.otpCodes});

  /// Overridable for tests; defaults to the build-time setting.
  final bool useCodes;

  @override
  Widget build(BuildContext context) =>
      useCodes ? const _CodeResetForm() : const _SupportResetInfo();
}

class _SupportResetInfo extends StatelessWidget {
  const _SupportResetInfo();

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

class _CodeResetForm extends ConsumerStatefulWidget {
  const _CodeResetForm();

  @override
  ConsumerState<_CodeResetForm> createState() => _CodeResetFormState();
}

class _CodeResetFormState extends ConsumerState<_CodeResetForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // Validation stays off until the first failed submit, then revalidates live
  // so a corrected field clears its error without a second tap.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, _handleAuthState);
    final authState = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Forgot Password',
      subtitle: 'Enter your email and we will send a 6-digit code.',
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _emailController,
              labelText: 'Email',
              prefixIcon: Icons.contact_mail_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Send Code',
              icon: Icons.send_outlined,
              isLoading: authState.isLoading,
              onPressed: authState.isLoading ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            LuxuryTextButton(
              label: 'Back to sign in',
              onPressed: () => context.go(AppRoutes.login),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    await ref
        .read(authProvider.notifier)
        .sendPasswordResetCode(_emailController.text.trim());
  }

  void _handleAuthState(AuthState? previous, AuthState next) {
    if (next.status == AuthStatus.success && next.message != null) {
      LuxurySnackBars.success(context, next.message!);
      ref.read(authProvider.notifier).startOtpCountdown();
      context.go('${AppRoutes.otp}?flow=forgotPassword');
      ref.read(authProvider.notifier).clearStatus();
    }
    if (next.status == AuthStatus.failure && next.message != null) {
      LuxurySnackBars.error(context, next.message!);
    }
  }
}
