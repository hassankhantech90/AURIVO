// Lightweight date formatting for the orders UI (no `intl` dependency).

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a timestamp as e.g. `11 Aug 2026`, in the device's local time.
String formatOrderDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// Formats a timestamp as e.g. `11 Aug 2026, 14:05`, in the device's local time.
String formatOrderDateTime(DateTime dt) {
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${formatOrderDate(dt)}, $hh:$mm';
}
