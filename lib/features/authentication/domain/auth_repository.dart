import 'entities/auth_result.dart';

/// Repository contract for authentication workflows.
abstract class AuthRepository {
  Future<AuthResult> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  });

  Future<AuthResult> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  });

  Future<AuthResult> verifyOtp({required String otp});

  Future<AuthResult> resendOtp();

  Future<AuthResult> sendPasswordResetCode({required String identifier});

  Future<AuthResult> resetPassword({required String password});

  Future<AuthResult> continueAsGuest();

  /// Whether a legitimate recovery OTP has been verified and a password reset is
  /// currently permitted. The single authoritative, in-memory recovery
  /// authorization signal — read-only so it can never be forged from outside the
  /// repository. Becomes true only after a successful recovery-flow OTP verify
  /// and is revoked on reset, sign-out, or the start of any other auth flow.
  bool get isRecoveryAuthorized;
}
