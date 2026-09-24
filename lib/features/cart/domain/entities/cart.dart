import '../../../../core/utils/db_parsing.dart';

/// Shopping cart header (`public.carts`). Totals are maintained authoritatively
/// by the database (the `recalculate_cart_totals` trigger); never recompute them
/// on the client. The `guest_token` is intentionally not surfaced.
class Cart {
  const Cart({
    required this.id,
    this.profileId,
    this.status = 'active',
    this.currency = 'PKR',
    this.subtotal = 0,
    this.discountTotal = 0,
    this.grandTotal = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? profileId;
  final String status;
  final String currency;
  final double subtotal;
  final double discountTotal;
  final double grandTotal;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isGuest => profileId == null;

  /// Only for optimistic UI: recomputed totals shown instantly while a cart
  /// mutation is in flight. The database-authoritative totals replace these as
  /// soon as the write returns — never treat a client-set total as canonical.
  Cart copyWith({double? subtotal, double? grandTotal}) => Cart(
    id: id,
    profileId: profileId,
    status: status,
    currency: currency,
    subtotal: subtotal ?? this.subtotal,
    discountTotal: discountTotal,
    grandTotal: grandTotal ?? this.grandTotal,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory Cart.fromMap(Map<String, dynamic> map) {
    return Cart(
      id: map['id'] as String,
      profileId: map['profile_id'] as String?,
      status: map['status'] as String? ?? 'active',
      currency: map['currency'] as String? ?? 'PKR',
      subtotal: parseDouble(map['subtotal']),
      discountTotal: parseDouble(map['discount_total']),
      grandTotal: parseDouble(map['grand_total']),
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
