/// Parses a Supabase ISO-8601 timestamp string into a [DateTime].
DateTime? parseTimestamp(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
