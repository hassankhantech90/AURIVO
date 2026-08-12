/// Editable quote fields captured by the seller quote form. `seller_profile_id`
/// and `rfq_id` are never part of this draft — ownership is resolved
/// server-side (current seller profile) and the RFQ is fixed by context.
class QuoteDraft {
  const QuoteDraft({
    required this.unitPrice,
    required this.totalPrice,
    this.minimumOrderQuantity = 1,
    this.currency = 'PKR',
    this.leadTimeDays,
    this.validUntil,
    this.message,
    this.status = 'sent',
  });

  final double unitPrice;
  final double totalPrice;
  final int minimumOrderQuantity;
  final String currency;
  final int? leadTimeDays;
  final DateTime? validUntil;
  final String? message;

  /// One of `draft` / `sent` / `withdrawn` (seller-controllable statuses).
  final String status;
}
