import 'quote.dart';
import 'rfq.dart';

/// Aggregate read shape for the RFQ detail screen: the request plus the quotes
/// received against it. Quotes are read-only buyer projections.
class RfqDetail {
  const RfqDetail({required this.rfq, this.quotes = const []});

  final Rfq rfq;
  final List<Quote> quotes;

  int get quoteCount => quotes.length;
  bool get hasQuotes => quotes.isNotEmpty;
}
