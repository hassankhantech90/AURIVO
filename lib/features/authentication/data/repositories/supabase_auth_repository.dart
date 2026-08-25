import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/supabase/supabase_auth_service.dart';
import '../../domain/auth_repository.dart';
import '../../domain/entities/auth_flow.dart';
import '../../domain/entities/auth_result.dart';
import '../auth_diagnostics.dart';
import '../auth_failure_mapper.dart';

/// Production authentication repository backed by Supabase Auth.
///
/// Implements the existing [AuthRepository] contract so the authentication
/// screens keep working unchanged. Supabase errors are mapped to the project's
/// [Failure] types via [AuthFailureMapper]. Profile creation is intentionally
/// out of scope for this milestone.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({required SupabaseAuthService authService})
    : _authService = authService;

  final SupabaseAuthService _authService;

  // The OTP screens do not carry the email, so the flow email is tracked here
  // between requesting a code (signup / reset) and verifying it.
  String? _pendingEmail;
  AuthFlow? _pendingFlow;

  @override
  Future<AuthResult> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      await _authService.signIn(email: identifier.trim(), password: password);
      return const AuthResult(message: 'Welcome back to AURIVO');
    } catch (error) {
      AuthDiagnostics.report(error, stage: 'login');
      throw AuthFailureMapper.map(error);
    }
  }

  @override
  Future<AuthResult> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim();
      // Creates the Supabase Auth user only. Profile creation is a later
      // milestone and is intentionally not performed here.
      await _authService.signUp(
        email: normalizedEmail,
        password: password,
        data: {'full_name': fullName.trim(), 'phone': phone.trim()},
      );
      _pendingEmail = normalizedEmail;
      _pendingFlow = AuthFlow.signup;
      return const AuthResult(message: 'Account created. Verify your code.');
    } catch (error) {
      AuthDiagnostics.report(error, stage: 'signup');
      throw AuthFailureMapper.map(error);
    }
  }

  @override
  Future<AuthResult> verifyOtp({required String otp}) async {
    final email = _pendingEmail;
    final flow = _pendingFlow;
    if (email == null || flow == null) {
      throw const SessionExpiredFailure(
        message: 'Verification session expired. Please start again.',
      );
    }

    try {
      final type = flow == AuthFlow.forgotPassword
          ? supabase.OtpType.recovery
          : supabase.OtpType.signup;
      await _authService.verifyOtp(email: email, token: otp, type: type);
      return const AuthResult(message: 'Verification successful');
    } catch (error) {
      AuthDiagnostics.report(error, stage: 'verify_otp');
      throw AuthFailureMapper.map(error);
    }
  }

  @override
  Future<AuthResult> resendOtp() async {
    final email = _pendingEmail;
    final flow = _pendingFlow;
    if (email == null || flow == null) {
      throw const SessionExpiredFailure(
        message: 'Verification session expired. Please start again.',
      );
    }

    try {
      if (flow == AuthFlow.forgotPassword) {
        await _authService.resetPassword(email: email);
      } else {
        await _authService.resendSignupOtp(email: email);
      }
      return const AuthResult(message: 'A new code has been sent');
    } catch (error) {
      throw AuthFailureMapper.map(error);
    }
  }

  @override
  Future<AuthResult> sendPasswordResetCode({required String identifier}) async {
    try {
      final email = identifier.trim();
      await _authService.resetPassword(email: email);
      _pendingEmail = email;
      _pendingFlow = AuthFlow.forgotPassword;
      return const AuthResult(message: 'Password reset code sent');
    } catch (error) {
      throw AuthFailureMapper.map(error);
    }
  }

  @override
  Future<AuthResult> resetPassword({required String password}) async {
    try {
      await _authService.updatePassword(password: password);
      _pendingEmail = null;
      _pendingFlow = null;
      return const AuthResult(message: 'Password updated successfully');
    } catch (error) {
      throw AuthFailureMapper.map(error);
    }
  }

  @override
  Future<AuthResult> continueAsGuest() async {
    return const AuthResult(message: 'Continuing as guest');
  }

  /// Current authenticated Supabase user, or null when signed out.
  supabase.User? getCurrentUser() => _authService.currentUser;

  /// Stream of Supabase auth state changes for session synchronization.
  Stream<supabase.AuthState> authStateChanges() =>
      _authService.authStateChanges;

  /// Signs out from Supabase and clears any in-flight verification state.
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _pendingEmail = null;
      _pendingFlow = null;
    } catch (error) {
      throw AuthFailureMapper.map(error);
    }
  }
}
