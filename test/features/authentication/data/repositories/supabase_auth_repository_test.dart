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
  Object? updateError;
  Object? signOutError;

  String? lastSignInEmail;
  Map<String, dynamic>? lastSignUpData;
  supabase.User? signUpUser; // when set, returned in the signUp response
  String? lastVerifyEmail;
  supabase.OtpType? lastVerifyType;
  bool resendSignupCalled = false;
  bool resetCalled = false;
  bool updateCalled = false;
  int updateCount = 0;
  bool signOutCalled = false;

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
    return supabase.AuthResponse(user: signUpUser);
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
    if (updateError != null) throw updateError!;
    updateCalled = true;
    updateCount++;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    if (signOutError != null) throw signOutError!;
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
      expect(result.message, contains('Check your email'));
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

    test('an already-registered email (empty identities) is rejected', () async {
      // Supabase anti-enumeration: signUp succeeds but returns a user with no
      // identities and sends no email.
      service.signUpUser = supabase.User(
        id: 'existing-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
        identities: const [],
      );

      await expectLater(
        repository.signup(
          fullName: 'Aya Khan',
          email: 'existing@aurivo.pk',
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
      await repository.sendPasswordResetCode(identifier: 'aya@aurivo.pk');
      await repository.verifyOtp(otp: '123456');

      final result = await repository.resetPassword(password: 'NewSecret123!');

      expect(service.updateCalled, isTrue);
      expect(result.message, contains('updated'));
    });
  });

  group('recovery authorization gate', () {
    Future<void> authorizeRecovery() async {
      await repository.sendPasswordResetCode(identifier: 'aya@aurivo.pk');
      await repository.verifyOtp(otp: '123456');
    }

    test('reset without recovery verification throws and does not update', () async {
      await expectLater(
        repository.resetPassword(password: 'NewSecret123!'),
        throwsA(isA<SessionExpiredFailure>()),
      );
      expect(service.updateCalled, isFalse);
    });

    test('a normal login does not authorize a reset', () async {
      await repository.login(
        identifier: 'aya@aurivo.pk',
        password: 'Secret123!',
        rememberMe: false,
      );

      expect(repository.isRecoveryAuthorized, isFalse);
      await expectLater(
        repository.resetPassword(password: 'NewSecret123!'),
        throwsA(isA<SessionExpiredFailure>()),
      );
      expect(service.updateCalled, isFalse);
    });

    test('signup OTP verification does not authorize a reset', () async {
      await repository.signup(
        fullName: 'Aya Khan',
        email: 'aya@aurivo.pk',
        phone: '03001234567',
        password: 'Secret123!',
      );
      await repository.verifyOtp(otp: '123456');

      expect(repository.isRecoveryAuthorized, isFalse);
      await expectLater(
        repository.resetPassword(password: 'NewSecret123!'),
        throwsA(isA<SessionExpiredFailure>()),
      );
      expect(service.updateCalled, isFalse);
    });

    test('sending a reset code alone does not authorize', () async {
      await repository.sendPasswordResetCode(identifier: 'aya@aurivo.pk');

      expect(repository.isRecoveryAuthorized, isFalse);
    });

    test('a verified recovery OTP authorizes a reset', () async {
      await authorizeRecovery();

      expect(repository.isRecoveryAuthorized, isTrue);
    });

    test('an authorized reset updates once, clears auth, and signs out', () async {
      await authorizeRecovery();

      final result = await repository.resetPassword(password: 'NewSecret123!');

      expect(result.message, contains('updated'));
      expect(service.updateCount, 1);
      expect(service.signOutCalled, isTrue);
      expect(repository.isRecoveryAuthorized, isFalse);
      // Pending recovery state cleared: a follow-up verify is now rejected.
      await expectLater(
        repository.verifyOtp(otp: '123456'),
        throwsA(isA<SessionExpiredFailure>()),
      );
    });

    test('a transient update failure keeps authorization and does not sign out', () async {
      await authorizeRecovery();
      service.updateError = Exception('Network error: connection failed');

      await expectLater(
        repository.resetPassword(password: 'NewSecret123!'),
        throwsA(isA<NetworkFailure>()),
      );
      expect(repository.isRecoveryAuthorized, isTrue);
      expect(service.signOutCalled, isFalse);

      // Retry remains possible once the transient error clears.
      service.updateError = null;
      final result = await repository.resetPassword(password: 'NewSecret123!');
      expect(result.message, contains('updated'));
    });

    test('a weak-password backend failure keeps authorization', () async {
      await authorizeRecovery();
      service.updateError = supabase.AuthException(
        'Password should be at least 8 characters',
        code: 'weak_password',
      );

      await expectLater(
        repository.resetPassword(password: 'weak'),
        throwsA(isA<WeakPasswordFailure>()),
      );
      expect(repository.isRecoveryAuthorized, isTrue);
    });

    test('a session-expired update failure clears authorization', () async {
      await authorizeRecovery();
      service.updateError = supabase.AuthException(
        'Auth session missing!',
        code: 'session_not_found',
      );

      await expectLater(
        repository.resetPassword(password: 'NewSecret123!'),
        throwsA(isA<SessionExpiredFailure>()),
      );
      expect(repository.isRecoveryAuthorized, isFalse);
      // Pending recovery state cleared too.
      await expectLater(
        repository.verifyOtp(otp: '123456'),
        throwsA(isA<SessionExpiredFailure>()),
      );
    });

    test('a failed local sign-out does not fail the successful reset', () async {
      await authorizeRecovery();
      service.signOutError = supabase.AuthException('sign-out failed');

      final result = await repository.resetPassword(password: 'NewSecret123!');

      expect(result.message, contains('updated'));
      expect(service.updateCount, 1);
      expect(service.signOutCalled, isTrue);
      expect(repository.isRecoveryAuthorized, isFalse);
      // No automatic second update; a further reset is blocked.
      await expectLater(
        repository.resetPassword(password: 'Another1!'),
        throwsA(isA<SessionExpiredFailure>()),
      );
      expect(service.updateCount, 1);
    });

    test('starting login clears a prior authorization', () async {
      await authorizeRecovery();
      expect(repository.isRecoveryAuthorized, isTrue);

      await repository.login(
        identifier: 'aya@aurivo.pk',
        password: 'Secret123!',
        rememberMe: false,
      );

      expect(repository.isRecoveryAuthorized, isFalse);
    });

    test('starting signup clears a prior authorization', () async {
      await authorizeRecovery();
      expect(repository.isRecoveryAuthorized, isTrue);

      await repository.signup(
        fullName: 'Aya Khan',
        email: 'aya@aurivo.pk',
        phone: '03001234567',
        password: 'Secret123!',
      );

      expect(repository.isRecoveryAuthorized, isFalse);
    });

    test('a new forgot-password request clears a prior authorization', () async {
      await authorizeRecovery();
      expect(repository.isRecoveryAuthorized, isTrue);

      await repository.sendPasswordResetCode(identifier: 'aya@aurivo.pk');

      expect(repository.isRecoveryAuthorized, isFalse);
    });

    test('explicit sign-out clears authorization', () async {
      await authorizeRecovery();
      expect(repository.isRecoveryAuthorized, isTrue);

      await repository.signOut();

      expect(repository.isRecoveryAuthorized, isFalse);
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
