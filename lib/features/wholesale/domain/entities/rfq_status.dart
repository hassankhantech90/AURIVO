/// Status value set for `rfqs.status` (mirrors the live CHECK constraint).
class RfqStatus {
  const RfqStatus._();

  static const open = 'open';
  static const quoted = 'quoted';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
  static const expired = 'expired';
  static const cancelled = 'cancelled';
  static const closed = 'closed';

  static const all = <String>[
    open,
    quoted,
    accepted,
    rejected,
    expired,
    cancelled,
    closed,
  ];

  /// A buyer may cancel while the request is still active.
  static bool isCancellable(String status) =>
      status == open || status == quoted;

  static bool isTerminal(String status) =>
      status == accepted ||
      status == rejected ||
      status == expired ||
      status == cancelled ||
      status == closed;

  static String label(String status) {
    switch (status) {
      case open:
        return 'Open';
      case quoted:
        return 'Quoted';
      case accepted:
        return 'Accepted';
      case rejected:
        return 'Rejected';
      case expired:
        return 'Expired';
      case cancelled:
        return 'Cancelled';
      case closed:
        return 'Closed';
      default:
        return status;
    }
  }
}

/// Status value set for `quotes.status`.
class QuoteStatus {
  const QuoteStatus._();

  static const draft = 'draft';
  static const sent = 'sent';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
  static const expired = 'expired';
  static const withdrawn = 'withdrawn';

  static String label(String status) {
    switch (status) {
      case draft:
        return 'Draft';
      case sent:
        return 'Sent';
      case accepted:
        return 'Accepted';
      case rejected:
        return 'Rejected';
      case expired:
        return 'Expired';
      case withdrawn:
        return 'Withdrawn';
      default:
        return status;
    }
  }
}
