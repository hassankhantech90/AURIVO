import '../../domain/auth_repository.dart';
import '../../domain/entities/auth_result.dart';

/// Fake repository used until a backend is connected.
class FakeAuthRepository implements AuthRepository {
  const FakeAuthRepository({this.delay = const Duration(milliseconds: 450)});

  final Duration delay;

  @override
  Future<AuthResult> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    await Future<void>.delayed(delay);
    return const AuthResult(message: 'Welcome back to AURIVO');
  }

  @override
  Future<AuthResult> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(delay);
    return const AuthResult(message: 'Account created. Verify your code.');
  }

  @override
  Future<AuthResult> verifyOtp({required String otp}) async {
    await Future<void>.delayed(delay);
    if (otp != '123456') {
      throw const AuthException('Invalid verification code');
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
    await Future<void>.delayed(delay);
    return const AuthResult(message: 'Password reset code sent');
  }

  @override
  Future<AuthResult> resetPassword({required String password}) async {
    await Future<void>.delayed(delay);
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
