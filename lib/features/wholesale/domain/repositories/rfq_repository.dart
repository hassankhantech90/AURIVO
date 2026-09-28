import '../entities/rfq.dart';
import '../entities/rfq_detail.dart';

/// Contract for buyer-side request-for-quotation data.
///
/// The buyer identity (`buyer_profile_id`) is always resolved server-side via
/// `current_profile_id()` — it is never accepted from the UI. RFQ writes are
/// direct, RLS-governed table operations (there is no RFQ RPC). Quotes are
/// read-only to the buyer (sellers write them under their own RLS).
///
/// Implementations must never surface raw Supabase exceptions; all failures are
/// mapped to the shared `Failure` type.
abstract class RFQRepository {
  /// Creates an RFQ owned by the current buyer, returning the created row.
  /// [quantity] must be >= 1. Optional [productId]/[productVariantId]/
  /// [sellerProfileId] scope the request; [targetPrice]/[message] are hints.
  Future<Rfq> createRfq({
    required int quantity,
    String? productId,
    String? productVariantId,
    String? sellerProfileId,
    String? businessProfileId,
    double? targetPrice,
    String currency,
    String? message,
  });

  /// The current buyer's RFQs, newest first.
  Future<List<Rfq>> getMyRfqs({int limit, int offset});

  /// A single RFQ with the quotes received against it. RLS guarantees only the
  /// owning buyer (or a quoting seller / admin) can read it.
  Future<RfqDetail> getRfq(String rfqId);

  /// Cancels [rfqId] (sets status to `cancelled`). RLS scopes the update to the
  /// owning buyer; the server remains authoritative.
  Future<Rfq> cancelRfq(String rfqId);

  /// Accepts [quoteId] and creates a cash-on-delivery order shipping to
  /// [addressId], returning the new order id. The server (`accept_quote`)
  /// validates buyer ownership, quote/RFQ status, MOQ and stock, and marks the
  /// quote and RFQ accepted (sibling quotes rejected).
  Future<String> acceptQuote({
    required String quoteId,
    required String addressId,
  });
}
