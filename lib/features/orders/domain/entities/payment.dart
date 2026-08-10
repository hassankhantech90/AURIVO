import '../../../../core/utils/db_parsing.dart';
import 'order_status.dart';

/// A payment record for an order (`public.payments`).
///
/// Read-only from the buyer app. The single payment row is created by the
/// `checkout_cart` RPC (`provider = 'manual'`, `status = 'pending'`) and can
/// only be advanced by admins/back-office — buyers never insert or update it.
class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.provider,
    required this.method,
    this.status = PaymentStatus.pending,
    this.amount = 0,
    this.currency = 'PKR',
    this.transactionReference,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderId;
  final String provider;
  final String method;
  final String status;
  final double amount;
  final String currency;
  final String? transactionReference;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPaid => status == PaymentStatus.paid;

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      provider: map['provider'] as String,
      method: map['method'] as String,
      status: map['status'] as String? ?? PaymentStatus.pending,
      amount: parseDouble(map['amount']),
      currency: map['currency'] as String? ?? 'PKR',
      transactionReference: map['transaction_reference'] as String?,
      paidAt: parseTimestamp(map['paid_at']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
