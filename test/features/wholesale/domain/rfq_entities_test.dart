import 'package:aurivo/features/wholesale/domain/entities/quote.dart';
import 'package:aurivo/features/wholesale/domain/entities/rfq.dart';
import 'package:aurivo/features/wholesale/domain/entities/rfq_detail.dart';
import 'package:aurivo/features/wholesale/domain/entities/rfq_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rfq.fromMap', () {
    test('parses a full row', () {
      final rfq = Rfq.fromMap({
        'id': 'rfq-1',
        'buyer_profile_id': 'p1',
        'seller_profile_id': 's1',
        'product_id': 'prod-1',
        'quantity': 50,
        'target_price': 900,
        'currency': 'PKR',
        'message': 'bulk',
        'status': 'open',
      });
      expect(rfq.quantity, 50);
      expect(rfq.targetPrice, 900);
      expect(rfq.sellerProfileId, 's1');
      expect(rfq.isCancellable, isTrue);
      expect(rfq.isTerminal, isFalse);
    });

    test('defaults for a minimal row', () {
      final rfq = Rfq.fromMap({
        'id': 'rfq-2',
        'buyer_profile_id': 'p1',
        'quantity': 1,
      });
      expect(rfq.status, RfqStatus.open);
      expect(rfq.targetPrice, isNull);
      expect(rfq.productId, isNull);
    });
  });

  test('Quote.fromMap parses a seller quote', () {
    final quote = Quote.fromMap({
      'id': 'q1',
      'rfq_id': 'rfq-1',
      'seller_profile_id': 's1',
      'unit_price': 120,
      'total_price': 1200,
      'currency': 'PKR',
      'minimum_order_quantity': 10,
      'lead_time_days': 14,
      'status': 'sent',
    });
    expect(quote.unitPrice, 120);
    expect(quote.totalPrice, 1200);
    expect(quote.minimumOrderQuantity, 10);
    expect(quote.leadTimeDays, 14);
  });

  test('RfqStatus cancellable/terminal + labels', () {
    expect(RfqStatus.isCancellable('open'), isTrue);
    expect(RfqStatus.isCancellable('quoted'), isTrue);
    expect(RfqStatus.isCancellable('cancelled'), isFalse);
    expect(RfqStatus.isTerminal('accepted'), isTrue);
    expect(RfqStatus.label('open'), 'Open');
    expect(QuoteStatus.label('sent'), 'Sent');
  });

  test('RfqDetail exposes quote count', () {
    final detail = RfqDetail(
      rfq: Rfq.fromMap({
        'id': 'rfq-1',
        'buyer_profile_id': 'p1',
        'quantity': 5,
      }),
      quotes: [
        Quote.fromMap({
          'id': 'q1',
          'rfq_id': 'rfq-1',
          'seller_profile_id': 's1',
          'unit_price': 10,
          'total_price': 100,
        }),
      ],
    );
    expect(detail.quoteCount, 1);
    expect(detail.hasQuotes, isTrue);
  });
}
