import 'package:aurivo/features/authentication/data/auth_failure_mapper.dart';
import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAuthRepository', () {
    late FakeAuthRepository repository;

    setUp(() {
      repository = FakeAuthRepository(delay: Duration.zero);
    });

    test('logs in successfully', () async {
      final result = await repository.login(
        identifier: 'customer@aurivo.pk',
        password: 'Secret123!',
        rememberMe: true,
      );

      expect(result.message, contains('Welcome'));
    });

    test('verifies accepted OTP', () async {
      final result = await repository.verifyOtp(otp: '123456');

      expect(result.message, contains('successful'));
    });

    test('throws for invalid OTP', () async {
      expect(
        () => repository.verifyOtp(otp: '000000'),
        throwsA(isA<AuthException>()),
      );
    });

    test('sends reset code', () async {
      final result = await repository.sendPasswordResetCode(
        identifier: '03001234567',
      );

      expect(result.message, contains('sent'));
    });

    group('recovery authorization lifecycle', () {
      test('is not authorized before any recovery verification', () {
        expect(repository.isRecoveryAuthorized, isFalse);
      });

      test('forgot-password start alone does not authorize', () async {
        await repository.sendPasswordResetCode(identifier: 'aya@aurivo.pk');

        expect(repository.isRecoveryAuthorized, isFalse);
      });

      test('recovery verify authorizes; reset clears it', () async {
        await repository.sendPasswordResetCode(identifier: 'aya@aurivo.pk');
        await repository.verifyOtp(otp: '123456');
        expect(repository.isRecoveryAuthorized, isTrue);

        final result = await repository.resetPassword(password: 'NewSecret123!');

        expect(result.message, contains('updated'));
        expect(repository.isRecoveryAuthorized, isFalse);
      });

      test('signup OTP verification never authorizes a reset', () async {
        await repository.signup(
          fullName: 'Aya Khan',
          email: 'aya@aurivo.pk',
          phone: '03001234567',
          password: 'Secret123!',
        );
        await repository.verifyOtp(otp: '123456');

        expect(repository.isRecoveryAuthorized, isFalse);
        expect(
          () => repository.resetPassword(password: 'NewSecret123!'),
          throwsA(isA<SessionExpiredFailure>()),
        );
      });

      test('resetPassword without authorization throws SessionExpired', () {
        expect(
          () => repository.resetPassword(password: 'NewSecret123!'),
          throwsA(isA<SessionExpiredFailure>()),
        );
      });

      test('starting a new flow clears a prior authorization', () async {
        await repository.sendPasswordResetCode(identifier: 'aya@aurivo.pk');
        await repository.verifyOtp(otp: '123456');
        expect(repository.isRecoveryAuthorized, isTrue);

        await repository.login(
          identifier: 'aya@aurivo.pk',
          password: 'Secret123!',
          rememberMe: false,
        );

        expect(repository.isRecoveryAuthorized, isFalse);
      });
    });
  });
}
