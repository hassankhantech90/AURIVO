/// Base exception for Supabase infrastructure failures.
abstract class AppSupabaseException implements Exception {
  const AppSupabaseException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$message ($code)';
}

/// Configuration exception raised when Supabase credentials are unavailable.
class SupabaseConfigurationException extends AppSupabaseException {
  const SupabaseConfigurationException(super.message, {super.code});
}

/// Network exception raised for connectivity and transport failures.
class NetworkException extends AppSupabaseException {
  const NetworkException(super.message, {super.code});
}

/// Authentication exception raised for Supabase Auth failures.
class AuthException extends AppSupabaseException {
  const AuthException(super.message, {super.code});
}

/// Database exception raised for PostgreSQL and RPC failures.
class DatabaseException extends AppSupabaseException {
  const DatabaseException(super.message, {super.code});
}

/// Storage exception raised for Supabase Storage failures.
class StorageException extends AppSupabaseException {
  const StorageException(super.message, {super.code});
}

/// Maps SDK and platform errors to application-level Supabase exceptions.
class SupabaseExceptionMapper {
  const SupabaseExceptionMapper._();

  static AppSupabaseException auth(Object error) {
    return AuthException(_message(error), code: _code(error));
  }

  static AppSupabaseException database(Object error) {
    return DatabaseException(_message(error), code: _code(error));
  }

  static AppSupabaseException storage(Object error) {
    return StorageException(_message(error), code: _code(error));
  }

  static AppSupabaseException network(Object error) {
    return NetworkException(_message(error), code: _code(error));
  }

  static String _message(Object error) {
    final dynamic value = error;
    final Object? message = _readProperty(() => value.message);
    return message?.toString() ?? error.toString();
  }

  static String? _code(Object error) {
    final dynamic value = error;
    final Object? code = _readProperty(() => value.code);
    return code?.toString();
  }

  static Object? _readProperty(Object? Function() reader) {
    try {
      return reader();
    } catch (_) {
      return null;
    }
  }
}
