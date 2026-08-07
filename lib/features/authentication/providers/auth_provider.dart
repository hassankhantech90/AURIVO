import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    authService: const SupabaseAuthService(supabaseService: SupabaseService()),
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(repository: ref.watch(authRepositoryProvider));
});

/// Current status for authentication actions.
enum AuthStatus { initial, loading, success, failure }

/// UI state shared by authentication screens.
class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.message,
    this.rememberMe = false,
    this.acceptedTerms = false,
    this.otpSecondsRemaining = 60,
    this.canResendOtp = false,
  });

  final AuthStatus status;
  final String? message;
  final bool rememberMe;
  final bool acceptedTerms;
  final int otpSecondsRemaining;
  final bool canResendOtp;

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    String? message,
    bool clearMessage = false,
    bool? rememberMe,
    bool? acceptedTerms,
    int? otpSecondsRemaining,
    bool? canResendOtp,
  }) {
    return AuthState(
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
      rememberMe: rememberMe ?? this.rememberMe,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      otpSecondsRemaining: otpSecondsRemaining ?? this.otpSecondsRemaining,
      canResendOtp: canResendOtp ?? this.canResendOtp,
    );
  }
}

/// Riverpod controller for fake authentication workflows.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({required AuthRepository repository})
    : _repository = repository,
      super(const AuthState());

  final AuthRepository _repository;
  Timer? _otpTimer;

  void setRememberMe(bool value) {
    state = state.copyWith(rememberMe: value, clearMessage: true);
  }

  void setAcceptedTerms(bool value) {
    state = state.copyWith(acceptedTerms: value, clearMessage: true);
  }

  void clearStatus() {
    state = state.copyWith(status: AuthStatus.initial, clearMessage: true);
  }

  void startOtpCountdown() {
    _otpTimer?.cancel();
    state = state.copyWith(otpSecondsRemaining: 60, canResendOtp: false);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.otpSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(otpSecondsRemaining: 0, canResendOtp: true);
        return;
      }
      state = state.copyWith(otpSecondsRemaining: remaining);
    });
  }

  Future<void> login({required String identifier, required String password}) {
    return _run(
      () => _repository.login(
        identifier: identifier,
        password: password,
        rememberMe: state.rememberMe,
      ),
    );
  }

  Future<void> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) {
    return _run(
      () => _repository.signup(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      ),
    );
  }

  Future<void> verifyOtp(String otp) {
    return _run(() => _repository.verifyOtp(otp: otp));
  }

  Future<void> resendOtp() async {
    await _run(_repository.resendOtp);
    if (state.status == AuthStatus.success) {
      startOtpCountdown();
    }
  }

  Future<void> sendPasswordResetCode(String identifier) {
    return _run(
      () => _repository.sendPasswordResetCode(identifier: identifier),
    );
  }

  Future<void> resetPassword(String password) {
    return _run(() => _repository.resetPassword(password: password));
  }

  Future<void> continueAsGuest() {
    return _run(_repository.continueAsGuest);
  }

  Future<void> _run(Future<dynamic> Function() action) async {
    state = state.copyWith(status: AuthStatus.loading, clearMessage: true);
    try {
      final result = await action();
      final message = result.message as String;
      state = state.copyWith(status: AuthStatus.success, message: message);
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.failure,
        message: error.toString(),
      );
    }
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }
}
