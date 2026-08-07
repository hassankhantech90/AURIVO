import 'package:aurivo/features/authentication/domain/validators/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthValidators', () {
    test('accepts valid email', () {
      expect(AuthValidators.email('customer@aurivo.pk'), isNull);
    });

    test('rejects invalid email', () {
      expect(AuthValidators.email('customer'), isNotNull);
    });

    test('accepts Pakistan phone formats', () {
      expect(AuthValidators.pakistanPhone('03001234567'), isNull);
      expect(AuthValidators.pakistanPhone('+923001234567'), isNull);
    });

    test('rejects invalid Pakistan phone', () {
      expect(AuthValidators.pakistanPhone('0211234567'), isNotNull);
    });

    test('requires strong password', () {
      expect(AuthValidators.password('Weakpass1!'), isNull);
      expect(AuthValidators.password('weakpass1!'), contains('uppercase'));
      expect(AuthValidators.password('WEAKPASS1!'), contains('lowercase'));
      expect(AuthValidators.password('Weakpass!'), contains('number'));
      expect(AuthValidators.password('Weakpass1'), contains('special'));
    });

    test('validates confirm password', () {
      expect(
        AuthValidators.confirmPassword('Secret123!', 'Secret123!'),
        isNull,
      );
      expect(
        AuthValidators.confirmPassword('Secret123?', 'Secret123!'),
        isNotNull,
      );
    });

    test('validates OTP', () {
      expect(AuthValidators.otp('123456'), isNull);
      expect(AuthValidators.otp('12345'), isNotNull);
      expect(AuthValidators.otp('abcdef'), isNotNull);
    });
  });
}
