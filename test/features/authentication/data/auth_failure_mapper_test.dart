import 'package:aurivo/features/authentication/data/auth_failure_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

supabase.AuthException _authError(
  String message, {
  String? code,
  String? status,
}) {
  return supabase.AuthException(message, code: code, statusCode: status);
}

void main() {
  group('AuthFailureMapper', () {
    test('maps invalid credentials by code', () {
      final failure = AuthFailureMapper.map(
        _authError('Invalid login credentials', code: 'invalid_credentials'),
      );
      expect(failure, isA<InvalidCredentialsFailure>());
    });

    test('maps email already registered by code', () {
      final failure = AuthFailureMapper.map(
        _authError('User already registered', code: 'user_already_exists'),
      );
      expect(failure, isA<EmailAlreadyRegisteredFailure>());
    });

    test('maps weak password by code', () {
      final failure = AuthFailureMapper.map(
        _authError('Password is too weak', code: 'weak_password'),
      );
      expect(failure, isA<WeakPasswordFailure>());
    });

    test('maps email not confirmed by code', () {
      final failure = AuthFailureMapper.map(
        _authError('Email not confirmed', code: 'email_not_confirmed'),
      );
      expect(failure, isA<EmailNotConfirmedFailure>());
    });

    test('maps rate limit by code', () {
      final failure = AuthFailureMapper.map(
        _authError('Too many requests', code: 'over_email_send_rate_limit'),
      );
      expect(failure, isA<RateLimitFailure>());
    });

    test('maps rate limit by 429 status', () {
      final failure = AuthFailureMapper.map(
        _authError('Slow down', status: '429'),
      );
      expect(failure, isA<RateLimitFailure>());
    });

    test('maps session expired by code', () {
      final failure = AuthFailureMapper.map(
        _authError('Session not found', code: 'session_not_found'),
      );
      expect(failure, isA<SessionExpiredFailure>());
    });

    test('maps network error from message', () {
      final failure = AuthFailureMapper.map(
        _authError('AuthRetryableFetchException'),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test('maps unknown error to unexpected', () {
      final failure = AuthFailureMapper.map(Exception('boom'));
      expect(failure, isA<UnexpectedFailure>());
    });

    test('passes an existing Failure through unchanged', () {
      const original = SessionExpiredFailure();
      expect(AuthFailureMapper.map(original), same(original));
    });

    test('failure message is user facing via toString', () {
      final failure = AuthFailureMapper.map(
        _authError('Invalid login credentials', code: 'invalid_credentials'),
      );
      expect(failure.toString(), 'Invalid email or password.');
    });
  });
}
