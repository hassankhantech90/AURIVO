import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/checkout/data/checkout_failure_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passes through a raised RPC message (P0001) verbatim', () {
    final failure = CheckoutFailureMapper.map(
      const ex.DatabaseException(
        'Insufficient stock for Gold Ring.',
        code: 'P0001',
      ),
    );
    expect(failure.message, 'Insufficient stock for Gold Ring.');
    expect(failure.code, 'P0001');
  });

  test('maps network exceptions to a friendly message', () {
    final failure = CheckoutFailureMapper.map(const ex.NetworkException('x'));
    expect(failure.message, contains('Network error'));
  });

  test('maps auth exceptions to a sign-in prompt', () {
    final failure = CheckoutFailureMapper.map(const ex.AuthException('x'));
    expect(failure.message, contains('sign in'));
  });

  test('maps foreign-key violations to an availability message', () {
    final failure = CheckoutFailureMapper.map(
      const ex.DatabaseException('fk', code: '23503'),
    );
    expect(failure.message, contains('no longer available'));
  });

  test('returns an existing Failure unchanged', () {
    const original = Failure(message: 'already mapped');
    expect(identical(CheckoutFailureMapper.map(original), original), isTrue);
  });

  test('falls back to a generic message', () {
    final failure = CheckoutFailureMapper.map(Exception('weird'));
    expect(failure.message, isNotEmpty);
  });
}
