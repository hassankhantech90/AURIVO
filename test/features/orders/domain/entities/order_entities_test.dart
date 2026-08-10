import 'package:aurivo/features/orders/domain/entities/order.dart';
import 'package:aurivo/features/orders/domain/entities/order_detail.dart';
import 'package:aurivo/features/orders/domain/entities/order_item.dart';
import 'package:aurivo/features/orders/domain/entities/order_status.dart';
import 'package:aurivo/features/orders/domain/entities/order_status_event.dart';
import 'package:aurivo/features/orders/domain/entities/payment.dart';
import 'package:aurivo/features/orders/domain/entities/shipment.dart';
import 'package:aurivo/features/orders/domain/entities/tracking_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Order.fromMap', () {
    test('parses fields, numeric strings, and jsonb snapshots', () {
      final order = Order.fromMap({
        'id': 'o1',
        'order_number': 'AUR260811000001',
        'profile_id': 'p1',
        'address_id': 'a1',
        'status': 'pending',
        'payment_status': 'pending',
        'currency': 'PKR',
        'subtotal': '1500.00',
        'shipping_fee': 0,
        'discount_total': 0,
        'tax_total': 0,
        'grand_total': 1500,
        'shipping_address_snapshot': {'city': 'Karachi'},
        'billing_address_snapshot': {'city': 'Karachi'},
        'notes': 'Leave at door',
        'placed_at': '2026-08-11T10:00:00Z',
        'created_at': '2026-08-11T10:00:00Z',
        'updated_at': '2026-08-11T10:00:00Z',
      });

      expect(order.id, 'o1');
      expect(order.orderNumber, 'AUR260811000001');
      expect(order.subtotal, 1500.0);
      expect(order.grandTotal, 1500.0);
      expect(order.shippingAddressSnapshot['city'], 'Karachi');
      expect(order.notes, 'Leave at door');
      expect(order.placedAt, isNotNull);
      expect(order.isCancellable, isTrue);
      expect(order.isTerminal, isFalse);
    });

    test('defaults snapshots to empty maps when absent/non-object', () {
      final order = Order.fromMap({
        'id': 'o2',
        'order_number': 'AUR2',
        'profile_id': 'p1',
        'shipping_address_snapshot': null,
        'billing_address_snapshot': 'not-an-object',
      });
      expect(order.shippingAddressSnapshot, isEmpty);
      expect(order.billingAddressSnapshot, isEmpty);
      expect(order.status, OrderStatus.pending);
    });
  });

  test('OrderItem.fromMap parses snapshots and derived line total', () {
    final item = OrderItem.fromMap({
      'id': 'i1',
      'order_id': 'o1',
      'product_id': 'prod-1',
      'product_variant_id': 'var-1',
      'seller_id': 'seller-1',
      'product_title_snapshot': 'Gold Ring',
      'variant_title_snapshot': 'Size 7',
      'sku_snapshot': 'SKU-1',
      'image_path_snapshot': null,
      'unit_price': '750.00',
      'quantity': 2,
      'line_total': '1500.00',
      'currency': 'PKR',
    });
    expect(item.productTitleSnapshot, 'Gold Ring');
    expect(item.variantTitleSnapshot, 'Size 7');
    expect(item.unitPrice, 750.0);
    expect(item.quantity, 2);
    expect(item.lineTotal, 1500.0);
  });

  test('OrderStatusEvent.fromMap parses nullable fields', () {
    final event = OrderStatusEvent.fromMap({
      'id': 'e1',
      'order_id': 'o1',
      'status': 'pending',
      'changed_by': 'p1',
      'notes': 'Order placed.',
      'created_at': '2026-08-11T10:00:00Z',
    });
    expect(event.status, 'pending');
    expect(event.notes, 'Order placed.');
    expect(event.createdAt, isNotNull);
  });

  test('Payment.fromMap parses status and amount', () {
    final payment = Payment.fromMap({
      'id': 'pay-1',
      'order_id': 'o1',
      'provider': 'manual',
      'method': 'cash_on_delivery',
      'status': 'pending',
      'amount': '1500.00',
      'currency': 'PKR',
      'transaction_reference': null,
      'paid_at': null,
    });
    expect(payment.provider, 'manual');
    expect(payment.method, 'cash_on_delivery');
    expect(payment.amount, 1500.0);
    expect(payment.isPaid, isFalse);
  });

  test('Shipment.fromMap exposes hasTracking', () {
    final withTracking = Shipment.fromMap({
      'id': 's1',
      'order_id': 'o1',
      'courier': 'TCS',
      'tracking_number': 'TRK123',
      'status': 'shipped',
    });
    final without = Shipment.fromMap({
      'id': 's2',
      'order_id': 'o1',
      'status': 'pending',
    });
    expect(withTracking.hasTracking, isTrue);
    expect(without.hasTracking, isFalse);
  });

  test('TrackingEvent.fromMap parses event time', () {
    final event = TrackingEvent.fromMap({
      'id': 't1',
      'shipment_id': 's1',
      'status': 'in_transit',
      'location': 'Lahore Hub',
      'description': null,
      'event_time': '2026-08-12T09:00:00Z',
    });
    expect(event.shipmentId, 's1');
    expect(event.status, 'in_transit');
    expect(event.location, 'Lahore Hub');
    expect(event.eventTime, isNotNull);
  });

  group('OrderStatus helpers', () {
    test('isCancellable only for pending/confirmed', () {
      expect(OrderStatus.isCancellable('pending'), isTrue);
      expect(OrderStatus.isCancellable('confirmed'), isTrue);
      expect(OrderStatus.isCancellable('shipped'), isFalse);
      expect(OrderStatus.isCancellable('cancelled'), isFalse);
    });

    test('isTerminal for closed states', () {
      expect(OrderStatus.isTerminal('completed'), isTrue);
      expect(OrderStatus.isTerminal('cancelled'), isTrue);
      expect(OrderStatus.isTerminal('pending'), isFalse);
    });

    test('label falls back to raw value for unknown status', () {
      expect(OrderStatus.label('pending'), 'Pending');
      expect(OrderStatus.label('mystery'), 'mystery');
    });
  });

  test('OrderDetail.eventsForShipment filters by shipment id', () {
    final detail = OrderDetail(
      order: Order.fromMap({
        'id': 'o1',
        'order_number': 'AUR1',
        'profile_id': 'p1',
      }),
      items: [],
      trackingEvents: [
        TrackingEvent.fromMap({
          'id': 't1',
          'shipment_id': 's1',
          'status': 'shipped',
        }),
        TrackingEvent.fromMap({
          'id': 't2',
          'shipment_id': 's2',
          'status': 'shipped',
        }),
      ],
    );
    expect(detail.eventsForShipment('s1').length, 1);
    expect(detail.eventsForShipment('s1').first.id, 't1');
  });
}
