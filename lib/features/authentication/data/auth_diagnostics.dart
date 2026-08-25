import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Development-only, sanitized diagnostics for the auth/signup path.
///
/// The generic user-facing message ("Something went wrong") deliberately hides
/// the underlying error. In debug builds this logs just enough to diagnose a
/// failure — exception runtime type, error/status code, a sanitized message, and
/// which auth stage failed — while never emitting passwords, tokens, OTPs, keys,
/// or other secrets. It is a no-op in release builds.
class AuthDiagnostics {
  const AuthDiagnostics._();

  /// Builds the sanitized one-line description (pure; unit-testable).
  static String describe(Object error, {required String stage}) {
    final type = error.runtimeType.toString();
    final code = _read(() => (error as dynamic).code) ?? '-';
    final status = _read(() => (error as dynamic).statusCode) ?? '-';
    final rawMessage =
        _read(() => (error as dynamic).message) ?? error.toString();
    final message = _sanitize(rawMessage);
    return 'auth-diag stage=$stage type=$type code=$code status=$status message=$message';
  }

  /// Logs the sanitized description in debug builds only.
  static void report(Object error, {required String stage}) {
    if (!kDebugMode) return; // development-only
    developer.log(describe(error, stage: stage), name: 'aurivo.auth');
  }

  static String? _read(Object? Function() reader) {
    try {
      final value = reader();
      return value?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Defensive redaction: strip JWT-like tokens and Supabase key material, then
  /// cap length. The error object never carries the submitted password, but this
  /// guards against a message that echoes credentials.
  static String _sanitize(String input) {
    var out = input.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9._-]{10,}'),
      '<redacted-jwt>',
    );
    out = out.replaceAll(
      RegExp(r'sb_(secret|publishable)_[A-Za-z0-9]+'),
      '<redacted-key>',
    );
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (out.length > 300) out = '${out.substring(0, 300)}…';
    return out;
  }
}
