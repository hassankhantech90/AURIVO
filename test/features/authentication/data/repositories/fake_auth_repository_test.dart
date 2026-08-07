import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAuthRepository', () {
    const repository = FakeAuthRepository(delay: Duration.zero);

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
  });
}
