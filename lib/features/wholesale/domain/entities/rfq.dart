import '../../../../core/utils/db_parsing.dart';
import 'rfq_status.dart';

/// A buyer's request for quotation (`public.rfqs`).
///
/// `buyer_profile_id` is always resolved server-side from the authenticated
/// session (`current_profile_id()`); it is never accepted from the UI.
class Rfq {
  const Rfq({
    required this.id,
    required this.buyerProfileId,
    this.sellerProfileId,
    this.businessProfileId,
    this.productId,
    this.productVariantId,
    required this.quantity,
    this.targetPrice,
    this.currency = 'PKR',
    this.message,
    this.status = RfqStatus.open,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String buyerProfileId;
  final String? sellerProfileId;
  final String? businessProfileId;
  final String? productId;
  final String? productVariantId;
  final int quantity;
  final double? targetPrice;
  final String currency;
  final String? message;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCancellable => RfqStatus.isCancellable(status);
  bool get isTerminal => RfqStatus.isTerminal(status);

  factory Rfq.fromMap(Map<String, dynamic> map) {
    return Rfq(
      id: map['id'] as String,
      buyerProfileId: map['buyer_profile_id'] as String,
      sellerProfileId: map['seller_profile_id'] as String?,
      businessProfileId: map['business_profile_id'] as String?,
      productId: map['product_id'] as String?,
      productVariantId: map['product_variant_id'] as String?,
      quantity: parseInt(map['quantity']),
      targetPrice: parseDoubleOrNull(map['target_price']),
      currency: map['currency'] as String? ?? 'PKR',
      message: map['message'] as String?,
      status: map['status'] as String? ?? RfqStatus.open,
      expiresAt: parseTimestamp(map['expires_at']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
