// Small, null-safe helpers for mapping Supabase/PostgREST row values into
// Dart types inside entity `fromMap` factories.

/// Parses an ISO-8601 timestamp string into a [DateTime].
DateTime? parseTimestamp(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Parses a numeric value that may arrive as a `num` or a `String`.
num? parseNumOrNull(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

double parseDouble(Object? value, {double fallback = 0}) {
  return parseNumOrNull(value)?.toDouble() ?? fallback;
}

double? parseDoubleOrNull(Object? value) => parseNumOrNull(value)?.toDouble();

int parseInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
