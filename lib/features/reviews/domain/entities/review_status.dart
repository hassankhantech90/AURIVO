/// Moderation status value set for reviews (`product_reviews.status` /
/// `seller_reviews.status`).
///
/// Mirrors the live `CHECK` constraint. New and edited buyer reviews are forced
/// to `pending` server-side by the integrity trigger; only `approved` reviews
/// are publicly readable under RLS. The client never sends this value.
class ReviewStatus {
  const ReviewStatus._();

  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const hidden = 'hidden';

  static const all = <String>[pending, approved, rejected, hidden];

  static bool isPending(String status) => status == pending;
  static bool isApproved(String status) => status == approved;

  /// Human-friendly label for a buyer's own review status.
  static String label(String status) {
    switch (status) {
      case pending:
        return 'Pending approval';
      case approved:
        return 'Published';
      case rejected:
        return 'Rejected';
      case hidden:
        return 'Hidden';
      default:
        return status;
    }
  }
}
