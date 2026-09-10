import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/validators/auth_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/authentication_widgets.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, _handleAuthState);
    final authState = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Forgot Password',
      subtitle:
          'Enter your email and we will send a verification code.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _identifierController,
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
        .sendPasswordResetCode(_identifierController.text.trim());
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
