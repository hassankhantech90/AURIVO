import '../../../wholesale/domain/entities/quote.dart';
import '../../../wholesale/domain/entities/rfq.dart';
import '../entities/quote_draft.dart';

/// Contract for the seller side of RFQs / quotes.
///
/// RLS scopes what a seller may see and write:
/// - a seller can only READ RFQs whose `seller_profile_id` matches their store
///   (the inbox); untargeted/open RFQs are not seller-readable;
/// - a seller can create/update/delete quotes only for their own
///   `seller_profile_id`, which is resolved server-side and never supplied by
///   the UI.
///
/// Failures are mapped to the shared `Failure` type.
abstract class SellerRfqRepository {
  /// The current user's seller-profile id, or null if they are not a seller.
  Future<String?> mySellerProfileId();

  /// RFQs targeted at the current seller (newest first, excluding soft-deleted).
  Future<List<Rfq>> getInboxRfqs({int limit, int offset});

  /// A single RFQ visible to the seller (RLS enforces the match).
  Future<Rfq> getRfq(String rfqId);

  /// The seller's own quote for [rfqId], or null if none.
  Future<Quote?> getMyQuoteForRfq(String rfqId);

  /// Creates the seller's quote for [rfqId]. `seller_profile_id` is resolved
  /// server-side. The DB enforces `total_price >= unit_price * moq` and one
  /// quote per (rfq, seller).
  Future<Quote> createQuote(String rfqId, QuoteDraft draft);

  /// Updates the seller's own quote [quoteId].
  Future<Quote> updateQuote(String quoteId, QuoteDraft draft);

  /// Hard-deletes the seller's own quote [quoteId] (frees the unique
  /// `(rfq_id, seller_profile_id)` slot and removes it from the buyer's view).
  Future<void> deleteQuote(String quoteId);
}
