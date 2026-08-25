import 'package:aurivo/features/authentication/data/auth_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthError {
  _FakeAuthError(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final String? statusCode;
  @override
  String toString() => 'FakeAuthError($message)';
}

void main() {
  test('describe includes stage, type, code, status, and message', () {
    final d = AuthDiagnostics.describe(
      _FakeAuthError('boom', code: 'weak_password', statusCode: '400'),
      stage: 'signup',
    );
    expect(d, contains('stage=signup'));
    expect(d, contains('type=_FakeAuthError'));
    expect(d, contains('code=weak_password'));
    expect(d, contains('status=400'));
    expect(d, contains('message=boom'));
  });

  test('missing code/status render as -', () {
    final d = AuthDiagnostics.describe(_FakeAuthError('x'), stage: 'login');
    expect(d, contains('code=-'));
    expect(d, contains('status=-'));
  });

  test('redacts JWT-like tokens and sb_ keys (never leaks credentials)', () {
    final d = AuthDiagnostics.describe(
      _FakeAuthError(
        'bad sb_publishable_abc123 and '
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9payload',
      ),
      stage: 'signup',
    );
    expect(d, isNot(contains('sb_publishable_abc123')));
    expect(d, contains('<redacted-key>'));
    expect(d, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
    expect(d, contains('<redacted-jwt>'));
  });

  test('falls back to toString when there is no message field', () {
    final d = AuthDiagnostics.describe('plain string error', stage: 'x');
    expect(d, contains('type=String'));
    expect(d, contains('message=plain string error'));
  });

  test('caps very long messages', () {
    final d = AuthDiagnostics.describe(_FakeAuthError('a' * 500), stage: 'x');
    expect(d.length, lessThan(400));
    expect(d, contains('…'));
  });
}
