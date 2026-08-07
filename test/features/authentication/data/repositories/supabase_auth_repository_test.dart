import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/data/auth_failure_mapper.dart';
import 'package:aurivo/features/authentication/data/repositories/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Hand-written stub of [SupabaseAuthService] so the repository can be tested
/// without a live Supabase client (no mocking package required).
class _StubAuthService extends SupabaseAuthService {
  _StubAuthService() : super(supabaseService: const SupabaseService());

  Object? signInError;
  Object? signUpError;
  Object? verifyError;

  String? lastSignInEmail;
  Map<String, dynamic>? lastSignUpData;
  String? lastVerifyEmail;
  supabase.OtpType? lastVerifyType;
  bool resendSignupCalled = false;
  bool resetCalled = false;
  bool updateCalled = false;

  @override
  Future<supabase.AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    lastSignInEmail = email;
    return supabase.AuthResponse();
  }

  @override
  Future<supabase.AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    if (signUpError != null) throw signUpError!;
    lastSignUpData = data;
    return supabase.AuthResponse();
  }

  @override
  Future<supabase.AuthResponse> verifyOtp({
    required String email,
    required String token,
    required supabase.OtpType type,
  }) async {
    if (verifyError != null) throw verifyError!;
    lastVerifyEmail = email;
    lastVerifyType = type;
    return supabase.AuthResponse();
  }

  @override
  Future<void> resetPassword({required String email}) async {
    resetCalled = true;
  }

  @override
  Future<void> resendSignupOtp({required String email}) async {
    resendSignupCalled = true;
  }

  @override
  Future<void> updatePassword({required String password}) async {
    updateCalled = true;
  }
}

void main() {
  late _StubAuthService service;
  late SupabaseAuthRepository repository;

  setUp(() {
    service = _StubAuthService();
    repository = SupabaseAuthRepository(authService: service);
  });

  group('login', () {
    test('signs in with a trimmed email and returns a message', () async {
      final result = await repository.login(
        identifier: '  customer@aurivo.pk ',
        password: 'Secret123!',
        rememberMe: true,
      );

      expect(service.lastSignInEmail, 'customer@aurivo.pk');
      expect(result.message, contains('Welcome'));
    });

    test('maps invalid credentials to InvalidCredentialsFailure', () async {
      service.signInError = supabase.AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );

      await expectLater(
        repository.login(
          identifier: 'customer@aurivo.pk',
          password: 'wrong',
          rememberMe: false,
        ),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
    });
  });

  group('signup', () {
    test('creates the auth user with metadata and returns a message', () async {
      final result = await repository.signup(
        fullName: 'Aya Khan',
        email: 'aya@aurivo.pk',
        phone: '03001234567',
        password: 'Secret123!',
      );

      expect(service.lastSignUpData?['full_name'], 'Aya Khan');
      expect(service.lastSignUpData?['phone'], '03001234567');
      expect(result.message, contains('Verify'));
    });

    test('maps email already registered to a failure', () async {
      service.signUpError = supabase.AuthException(
        'User already registered',
        code: 'user_already_exists',
      );

      await expectLater(
        repository.signup(
          fullName: 'Aya Khan',
          email: 'aya@aurivo.pk',
          phone: '03001234567',
          password: 'Secret123!',
        ),
        throwsA(isA<EmailAlreadyRegisteredFailure>()),
      );
    });
  });

  group('otp verification', () {
    test('signup flow verifies with the signup OTP type', () async {
      await repository.signup(
        fullName: 'Aya Khan',
        email: 'aya@aurivo.pk',
        phone: '03001234567',
        password: 'Secret123!',
      );

      await repository.verifyOtp(otp: '123456');

      expect(service.lastVerifyEmail, 'aya@aurivo.pk');
      expect(service.lastVerifyType, supabase.OtpType.signup);
    });

    test('forgot-password flow verifies with the recovery OTP type', () async {
      await repository.sendPasswordResetCode(identifier: 'aya@aurivo.pk');

      await repository.verifyOtp(otp: '123456');

      expect(service.lastVerifyType, supabase.OtpType.recovery);
    });

    test('throws when there is no pending verification flow', () async {
      await expectLater(
        repository.verifyOtp(otp: '123456'),
        throwsA(isA<SessionExpiredFailure>()),
      );
    });
  });

  group('resend otp', () {
    test('resends a signup code after signup', () async {
      await repository.signup(
        fullName: 'Aya Khan',
        email: 'aya@aurivo.pk',
        phone: '03001234567',
        password: 'Secret123!',
      );

      await repository.resendOtp();

      expect(service.resendSignupCalled, isTrue);
    });

    test('resends a recovery code after a reset request', () async {
      await repository.sendPasswordResetCode(identifier: 'aya@aurivo.pk');
      service.resetCalled = false;

      await repository.resendOtp();

      expect(service.resetCalled, isTrue);
    });
  });

  group('update password', () {
    test('updates the password and returns a message', () async {
      final result = await repository.resetPassword(password: 'NewSecret123!');

      expect(service.updateCalled, isTrue);
      expect(result.message, contains('updated'));
    });
  });

  group('continue as guest', () {
    test('returns a guest message without calling Supabase', () async {
      final result = await repository.continueAsGuest();

      expect(result.message, contains('guest'));
      expect(service.lastSignInEmail, isNull);
    });
  });
}
