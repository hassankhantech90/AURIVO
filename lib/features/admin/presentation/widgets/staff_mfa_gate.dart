import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../data/staff_mfa_service.dart';

/// Requires two-factor authentication before showing [child] (the staff
/// console): enrol an authenticator app the first time, then enter its code
/// on each new session.
class StaffMfaGate extends ConsumerWidget {
  const StaffMfaGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffMfaStateProvider);
    return state.when(
      loading: () => const Center(child: LoadingIndicator()),
      error: (_, _) => ErrorStateWidget(
        message: 'Could not check two-factor authentication.',
        onRetry: () => ref.invalidate(staffMfaStateProvider),
      ),
      data: (s) => switch (s) {
        StaffMfaState.satisfied => child,
        StaffMfaState.needsEnrolment => const _EnrolView(),
        StaffMfaState.needsCode => const _CodeView(),
      },
    );
  }
}

class _EnrolView extends ConsumerStatefulWidget {
  const _EnrolView();

  @override
  ConsumerState<_EnrolView> createState() => _EnrolViewState();
}

class _EnrolViewState extends ConsumerState<_EnrolView> {
  TotpSetup? _setup;
  bool _busy = false;
  String? _error;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final setup = await ref.read(staffMfaServiceProvider).startEnrolment();
      if (mounted) setState(() => _setup = setup);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not start set-up. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final setup = _setup;
    if (setup == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(staffMfaServiceProvider)
          .verify(setup.factorId, _code.text);
      ref.invalidate(staffMfaStateProvider);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'That code did not match. Check the time on your phone and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setup = _setup;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Icon(
          Icons.shield_outlined,
          size: 48,
          color: AppColors.primaryGold,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Set up two-factor authentication',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Staff accounts must use an authenticator app (Google Authenticator, '
          'Microsoft Authenticator, Authy…). You will enter a 6-digit code each '
          'time you open the staff console on a new session.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (setup == null)
          LoadingButton(
            label: 'Start set-up',
            isLoading: _busy,
            onPressed: _busy ? null : _start,
          )
        else ...[
          Text(
            '1. Add this key to your authenticator app',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          LuxuryCard(
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    setup.secret,
                    style: theme.textTheme.titleMedium?.copyWith(
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy key',
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: setup.secret));
                    LuxurySnackBars.success(context, 'Key copied.');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'In the app choose "Enter a setup key", name it Pareezay.Hub, and paste '
            'this key (time-based).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '2. Enter the 6-digit code it shows',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CodeField(controller: _code, onSubmitted: (_) => _confirm()),
          const SizedBox(height: AppSpacing.md),
          LoadingButton(
            label: 'Verify & continue',
            isLoading: _busy,
            onPressed: _busy ? null : _confirm,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
      ],
    );
  }
}

class _CodeView extends ConsumerStatefulWidget {
  const _CodeView();

  @override
  ConsumerState<_CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends ConsumerState<_CodeView> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(staffMfaServiceProvider).verifyExisting(_code.text);
      ref.invalidate(staffMfaStateProvider);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'That code did not match. Try the latest one.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Icon(
          Icons.lock_clock_outlined,
          size: 48,
          color: AppColors.primaryGold,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Enter your authentication code',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Open your authenticator app and enter the 6-digit code for Pareezay.Hub.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        _CodeField(controller: _code, onSubmitted: (_) => _verify()),
        const SizedBox(height: AppSpacing.md),
        LoadingButton(
          label: 'Verify',
          isLoading: _busy,
          onPressed: _busy ? null : _verify,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
      ],
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(letterSpacing: 8),
      decoration: const InputDecoration(counterText: '', hintText: '••••••'),
      onSubmitted: onSubmitted,
    );
  }
}
