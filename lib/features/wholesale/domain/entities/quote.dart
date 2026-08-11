import '../../../../core/utils/db_parsing.dart';
import 'rfq_status.dart';

/// A seller's quote in response to an RFQ (`public.quotes`).
///
/// Read-only from the buyer app — quotes are written exclusively by sellers
/// under RLS. The current schema has no "accepted quote" linkage on the RFQ, so
/// the buyer app never mutates a quote or marks one accepted.
class Quote {
  const Quote({
    required this.id,
    required this.rfqId,
    required this.sellerProfileId,
    required this.unitPrice,
    required this.totalPrice,
    this.currency = 'PKR',
    this.minimumOrderQuantity = 1,
    this.leadTimeDays,
    this.status = QuoteStatus.sent,
    this.validUntil,
    this.message,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String rfqId;
  final String sellerProfileId;
  final double unitPrice;
  final double totalPrice;
  final String currency;
  final int minimumOrderQuantity;
  final int? leadTimeDays;
  final String status;
  final DateTime? validUntil;
  final String? message;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Quote.fromMap(Map<String, dynamic> map) {
    return Quote(
      id: map['id'] as String,
      rfqId: map['rfq_id'] as String,
      sellerProfileId: map['seller_profile_id'] as String,
      unitPrice: parseDouble(map['unit_price']),
      totalPrice: parseDouble(map['total_price']),
      currency: map['currency'] as String? ?? 'PKR',
      minimumOrderQuantity: parseInt(
        map['minimum_order_quantity'],
        fallback: 1,
      ),
      leadTimeDays: map['lead_time_days'] == null
          ? null
          : parseInt(map['lead_time_days']),
      status: map['status'] as String? ?? QuoteStatus.sent,
      validUntil: parseTimestamp(map['valid_until']),
      message: map['message'] as String?,
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
