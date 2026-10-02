import '../../domain/auth_repository.dart';
import '../../domain/entities/auth_flow.dart';
import '../../domain/entities/auth_result.dart';
import '../auth_failure_mapper.dart';

/// Fake repository used until a backend is connected.
///
/// Models the same recovery authorization lifecycle as the production
/// [SupabaseAuthRepository] so tests cannot be looser than production: a
/// password reset is permitted only after a successful recovery-flow OTP verify.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.delay = const Duration(milliseconds: 450)});

  final Duration delay;

  // Pending verification flow (signup vs recovery), mirrored from the last
  // signup / sendPasswordResetCode call.
  AuthFlow? _pendingFlow;

  // Single authoritative, in-memory recovery authorization.
  bool _recoveryVerified = false;

  @override
  bool get isRecoveryAuthorized => _recoveryVerified;

  @override
  Future<AuthResult> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    _recoveryVerified = false;
    await Future<void>.delayed(delay);
    return const AuthResult(message: 'Welcome back to Pareezay.Hub');
  }

  @override
  Future<AuthResult> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _recoveryVerified = false;
    await Future<void>.delayed(delay);
    _pendingFlow = AuthFlow.signup;
    return const AuthResult(message: 'Account created. Verify your code.');
  }

  @override
  Future<AuthResult> verifyOtp({required String otp}) async {
    await Future<void>.delayed(delay);
    if (otp != '123456') {
      throw const AuthException('Invalid verification code');
    }
    // Only a verified recovery OTP authorizes a password reset. Signup OTP
    // verification must never grant it.
    if (_pendingFlow == AuthFlow.forgotPassword) {
      _recoveryVerified = true;
    }
    return const AuthResult(message: 'Verification successful');
  }

  @override
  Future<AuthResult> resendOtp() async {
    await Future<void>.delayed(delay);
    return const AuthResult(message: 'A new code has been sent');
  }

  @override
  Future<AuthResult> sendPasswordResetCode({required String identifier}) async {
    _recoveryVerified = false;
    await Future<void>.delayed(delay);
    _pendingFlow = AuthFlow.forgotPassword;
    return const AuthResult(message: 'Password reset code sent');
  }

  @override
  Future<AuthResult> resetPassword({required String password}) async {
    if (!_recoveryVerified) {
      throw const SessionExpiredFailure(
        message: 'Verification session expired. Please start again.',
      );
    }
    await Future<void>.delayed(delay);
    _recoveryVerified = false;
    _pendingFlow = null;
    return const AuthResult(message: 'Password updated successfully');
  }

  @override
  Future<AuthResult> continueAsGuest() async {
    await Future<void>.delayed(delay);
    return const AuthResult(message: 'Continuing as guest');
  }
}

/// Exception thrown by fake authentication actions.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
