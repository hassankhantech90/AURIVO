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

    test('accepts modern TLDs, plus-addressing and multi-label domains', () {
      for (final email in const [
        'test@example.com',
        'user.name@example.co.uk',
        'user+test@example.com',
        'test@aurivo.online',
        'name@brand.studio',
        'buyer@shop.jewelry',
      ]) {
        expect(AuthValidators.email(email), isNull, reason: email);
      }
    });

    test('rejects obviously malformed emails', () {
      for (final bad in const [
        'abc',
        'abc@',
        '@example.com',
        'abc@example',
        '   ',
      ]) {
        expect(AuthValidators.email(bad), isNotNull, reason: bad);
      }
    });

    test('invalid-email copy is unchanged', () {
      expect(AuthValidators.email('not-an-email'), 'Enter a valid email address');
    });

    test('emailOrPakistanPhone accepts modern email and valid PK phones', () {
      expect(AuthValidators.emailOrPakistanPhone('test@aurivo.online'), isNull);
      expect(AuthValidators.emailOrPakistanPhone('03001234567'), isNull);
      expect(AuthValidators.emailOrPakistanPhone('+923001234567'), isNull);
      expect(AuthValidators.emailOrPakistanPhone('3001234567'), isNull);
    });

    test('emailOrPakistanPhone rejects garbage with the correct copy', () {
      expect(
        AuthValidators.emailOrPakistanPhone('abc'),
        'Enter a valid email or Pakistan phone number',
      );
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

    test('loginPassword requires only a non-empty password', () {
      expect(AuthValidators.loginPassword(null), 'Password is required');
      expect(AuthValidators.loginPassword(''), 'Password is required');
      expect(AuthValidators.loginPassword('   '), 'Password is required');
      expect(AuthValidators.loginPassword('abc'), isNull);
      expect(AuthValidators.loginPassword('weak'), isNull);
      // Signup/Reset strength validator must stay strict.
      expect(AuthValidators.password('weak'), isNotNull);
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
