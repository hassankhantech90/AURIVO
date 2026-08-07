/// Base failure type used across the application.
///
/// Implements [Exception] so it can be thrown by repositories and surfaced to
/// the UI through `toString()`, which returns the user-facing [message].
class Failure implements Exception {
  const Failure({required this.message, this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
