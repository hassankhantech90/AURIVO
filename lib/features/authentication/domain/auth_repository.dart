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
}
