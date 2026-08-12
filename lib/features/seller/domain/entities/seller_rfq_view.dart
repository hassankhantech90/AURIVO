import '../../../wholesale/domain/entities/quote.dart';
import '../../../wholesale/domain/entities/rfq.dart';

/// Aggregate for the seller RFQ detail screen: the incoming request plus the
/// seller's own quote for it (if any).
class SellerRfqView {
  const SellerRfqView({required this.rfq, this.myQuote});

  final Rfq rfq;
  final Quote? myQuote;

  bool get hasQuote => myQuote != null;
}
