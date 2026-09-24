import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../providers/auth_provider.dart';
import '../widgets/authentication_widgets.dart';

/// Shown after signup. The account is created but must be confirmed by tapping
/// the verification link sent by email (Supabase's default confirmation email
/// is a link, not a code) — so this screen instructs the user rather than
/// asking for a code. Once confirmed, they return and sign in.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
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
      title: 'Verify your email',
      subtitle:
          'We sent a verification link to your email. Open it to activate '
          'your account, then sign in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 64,
              color: AppColors.primaryGold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            authState.canResendOtp
                ? 'Did not receive the email?'
                : 'Resend available in ${authState.otpSecondsRemaining}s',
            textAlign: TextAlign.center,
            // Explicit on-light colour: inline Text built above the
            // AuthScaffold light theme, on the white card.
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.charcoal),
          ),
          const SizedBox(height: AppSpacing.sm),
          LuxuryTextButton(
            label: 'Resend email',
            isLoading: authState.isLoading && authState.canResendOtp,
            onPressed: authState.canResendOtp && !authState.isLoading
                ? ref.read(authProvider.notifier).resendOtp
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Go to sign in',
            icon: Icons.login,
            onPressed: authState.isLoading
                ? null
                : () {
                    ref.read(authProvider.notifier).clearStatus();
                    context.go(AppRoutes.login);
                  },
          ),
        ],
      ),
    );
  }

  void _handleAuthState(AuthState? previous, AuthState next) {
    if (next.status == AuthStatus.success && next.message != null) {
      LuxurySnackBars.success(context, next.message!);
    } else if (next.status == AuthStatus.failure && next.message != null) {
      LuxurySnackBars.error(context, next.message!);
    }
  }
}
