import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/reviews/data/review_failure_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passes an existing Failure through unchanged', () {
    const failure = Failure(message: 'already there');
    expect(identical(ReviewFailureMapper.map(failure), failure), isTrue);
  });

  test('maps 23505 to an already-reviewed message', () {
    final result = ReviewFailureMapper.map(
      const ex.DatabaseException('dup', code: '23505'),
    );
    expect(result.message, 'You have already reviewed this product.');
    expect(result.code, '23505');
  });

  test('maps 23514 (rating check) to a rating message', () {
    final result = ReviewFailureMapper.map(
      const ex.DatabaseException('check', code: '23514'),
    );
    expect(result.message, 'Please choose a rating between 1 and 5.');
  });

  test('passes P0001 trigger messages through', () {
    final result = ReviewFailureMapper.map(
      const ex.DatabaseException('Some server rule.', code: 'P0001'),
    );
    expect(result.message, 'Some server rule.');
    expect(result.code, 'P0001');
  });

  test('maps RLS/permission errors to a not-allowed message', () {
    final result = ReviewFailureMapper.map(
      const ex.DatabaseException(
        'new row violates row-level security policy',
        code: '42501',
      ),
    );
    expect(result.message, 'You are not allowed to modify this review.');
  });

  test('maps network exceptions', () {
    final result = ReviewFailureMapper.map(const ex.NetworkException('down'));
    expect(result.message, contains('Network error'));
  });

  test('falls back for unknown errors', () {
    final result = ReviewFailureMapper.map(Exception('mystery'));
    expect(result.message, 'Something went wrong. Please try again.');
  });
}
