import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/auth_flow.dart';
import '../domain/validators/auth_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/authentication_widgets.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key, this.flow = AuthFlow.signup});

  final AuthFlow flow;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  String _otp = '';
  String? _otpError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).startOtpCountdown();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, _handleAuthState);
    final authState = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Verify Code',
      subtitle: 'Enter the 6-digit code sent to your email or phone.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthOtpField(
            hasError: _otpError != null,
            onChanged: (value) => setState(() {
              _otp = value;
              _otpError = null;
            }),
          ),
          if (_otpError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _otpError!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            authState.canResendOtp
                ? 'Did not receive a code?'
                : 'Resend available in ${authState.otpSecondsRemaining}s',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          LuxuryTextButton(
            label: 'Resend OTP',
            isLoading: authState.isLoading && authState.canResendOtp,
            onPressed: authState.canResendOtp && !authState.isLoading
                ? ref.read(authProvider.notifier).resendOtp
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Verify',
            icon: Icons.verified_outlined,
            isLoading: authState.isLoading,
            onPressed: authState.isLoading ? null : _verify,
          ),
        ],
      ),
    );
  }

  Future<void> _verify() async {
    final error = AuthValidators.otp(_otp);
    if (error != null) {
      setState(() => _otpError = error);
      return;
    }

    await ref.read(authProvider.notifier).verifyOtp(_otp);
  }

  void _handleAuthState(AuthState? previous, AuthState next) {
    if (next.status == AuthStatus.success && next.message != null) {
      LuxurySnackBars.success(context, next.message!);
      final route = widget.flow == AuthFlow.forgotPassword
          ? AppRoutes.resetPassword
          : AppRoutes.home;
      context.go(route);
      ref.read(authProvider.notifier).clearStatus();
    }

    if (next.status == AuthStatus.failure && next.message != null) {
      LuxurySnackBars.error(context, next.message!);
    }
  }
}
