import '../../../core/utils/failure.dart';

/// Authentication failures mapped from Supabase Auth errors.
///
/// Each type extends the shared [Failure] so the existing UI (which reads
/// `error.toString()`) shows a friendly, user-facing message.
class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure({String? message, super.code})
    : super(message: message ?? 'Invalid email or password.');
}

class EmailAlreadyRegisteredFailure extends Failure {
  const EmailAlreadyRegisteredFailure({String? message, super.code})
    : super(message: message ?? 'This email is already registered.');
}

class WeakPasswordFailure extends Failure {
  const WeakPasswordFailure({String? message, super.code})
    : super(
        message:
            message ?? 'Password is too weak. Please choose a stronger one.',
      );
}

class EmailNotConfirmedFailure extends Failure {
  const EmailNotConfirmedFailure({String? message, super.code})
    : super(message: message ?? 'Please confirm your email before signing in.');
}

class RateLimitFailure extends Failure {
  const RateLimitFailure({String? message, super.code})
    : super(
        message:
            message ?? 'Too many attempts. Please wait a moment and try again.',
      );
}

class NetworkFailure extends Failure {
  const NetworkFailure({String? message, super.code})
    : super(
        message:
            message ?? 'Network error. Check your connection and try again.',
      );
}

class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure({String? message, super.code})
    : super(
        message: message ?? 'Your session has expired. Please sign in again.',
      );
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure({String? message, super.code})
    : super(message: message ?? 'Something went wrong. Please try again.');
}

/// Maps Supabase Auth (and transport) errors into the project's [Failure] types.
class AuthFailureMapper {
  const AuthFailureMapper._();

  static Failure map(Object error) {
    // Already a domain failure – pass it through unchanged.
    if (error is Failure) {
      return error;
    }

    final String message = _message(error);
    final String? code = _code(error);
    final String? statusCode = _statusCode(error);
    final String lower = message.toLowerCase();
    final String typeName = error.runtimeType.toString().toLowerCase();

    // Network / transport errors first – these have no reliable error code.
    if (typeName.contains('socket') ||
        typeName.contains('retryablefetch') ||
        typeName.contains('timeout') ||
        typeName.contains('clientexception') ||
        _containsAny(lower, const [
          'socketexception',
          'failed host lookup',
          'network',
          'connection refused',
          'connection closed',
          'connection error',
          'connection timed out',
          'timed out',
          'timeout',
          'unreachable',
          'authretryablefetch',
        ])) {
      return NetworkFailure(code: code);
    }

    switch (code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return InvalidCredentialsFailure(code: code);
      case 'email_not_confirmed':
      case 'phone_not_confirmed':
        return EmailNotConfirmedFailure(code: code);
      case 'user_already_exists':
      case 'email_exists':
      case 'identity_already_exists':
        return EmailAlreadyRegisteredFailure(code: code);
      case 'weak_password':
        return WeakPasswordFailure(code: code);
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
      case 'over_sms_send_rate_limit':
        return RateLimitFailure(code: code);
      case 'session_not_found':
      case 'session_expired':
      case 'session_missing':
      case 'refresh_token_not_found':
      case 'refresh_token_already_used':
      case 'bad_jwt':
        return SessionExpiredFailure(code: code);
    }

    if (statusCode == '429') {
      return RateLimitFailure(code: code);
    }

    // Message-based fallbacks for SDK/runtime variations without a code.
    if (_containsAny(lower, const [
      'invalid login credentials',
      'invalid credentials',
    ])) {
      return InvalidCredentialsFailure(code: code);
    }
    if (_containsAny(lower, const [
      'email not confirmed',
      'not confirmed',
      'confirm your email',
    ])) {
      return EmailNotConfirmedFailure(code: code);
    }
    if (_containsAny(lower, const [
      'already registered',
      'already been registered',
      'already exists',
      'user already',
    ])) {
      return EmailAlreadyRegisteredFailure(code: code);
    }
    if (_containsAny(lower, const [
      'weak password',
      'password should be at least',
      'password is too short',
      'password should contain',
    ])) {
      return WeakPasswordFailure(code: code);
    }
    if (_containsAny(lower, const [
      'rate limit',
      'too many requests',
      'try again later',
    ])) {
      return RateLimitFailure(code: code);
    }
    if (_containsAny(lower, const [
      'jwt expired',
      'token has expired',
      'session expired',
      'session missing',
      'session not found',
    ])) {
      return SessionExpiredFailure(code: code);
    }

    return UnexpectedFailure(code: code);
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  static String _message(Object error) {
    final Object? message = _read(() => (error as dynamic).message);
    return message?.toString() ?? error.toString();
  }

  static String? _code(Object error) {
    return _read(() => (error as dynamic).code)?.toString();
  }

  static String? _statusCode(Object error) {
    return _read(() => (error as dynamic).statusCode)?.toString();
  }

  static Object? _read(Object? Function() reader) {
    try {
      return reader();
    } catch (_) {
      return null;
    }
  }
}
