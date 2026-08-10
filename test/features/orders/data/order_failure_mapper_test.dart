import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/orders/data/order_failure_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passes through a raised RPC message (P0001) verbatim', () {
    final failure = OrderFailureMapper.map(
      const ex.DatabaseException(
        'Order can no longer be cancelled.',
        code: 'P0001',
      ),
    );
    expect(failure.message, 'Order can no longer be cancelled.');
    expect(failure.code, 'P0001');
  });

  test('maps RLS/permission errors to a not-allowed message', () {
    final failure = OrderFailureMapper.map(
      const ex.DatabaseException('new row violates row-level security policy'),
    );
    expect(failure.message, contains('not allowed'));
  });

  test('maps network exceptions to a friendly message', () {
    final failure = OrderFailureMapper.map(const ex.NetworkException('x'));
    expect(failure.message, contains('Network error'));
  });

  test('returns an existing Failure unchanged', () {
    const original = Failure(message: 'already mapped');
    expect(identical(OrderFailureMapper.map(original), original), isTrue);
  });

  test('falls back to a generic message', () {
    final failure = OrderFailureMapper.map(Exception('weird'));
    expect(failure.message, isNotEmpty);
  });
}
