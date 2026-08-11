import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/coupons/domain/entities/coupon.dart';
import 'package:aurivo/features/coupons/domain/entities/coupon_redemption.dart';
import 'package:aurivo/features/coupons/domain/repositories/coupon_repository.dart';
import 'package:aurivo/features/coupons/providers/coupon_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCouponRepository implements CouponRepository {
  _FakeCouponRepository({this.redeemError});
  final Object? redeemError;
  int redeemCalls = 0;
  String? lastCode;
  String? lastOrderId;

  @override
  Future<List<Coupon>> getActiveCoupons({
    int limit = 20,
    int offset = 0,
  }) async => const [];

  @override
  Future<CouponRedemption> redeem({
    required String code,
    required String orderId,
  }) async {
    redeemCalls++;
    lastCode = code;
    lastOrderId = orderId;
    if (redeemError != null) throw redeemError!;
    return CouponRedemption(
      id: 'red-1',
      couponId: 'c1',
      profileId: 'p1',
      orderId: orderId,
      discountAmount: 250,
    );
  }
}

ProviderContainer _container(CouponRepository repo) {
  final container = ProviderContainer(
    overrides: [couponRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('apply success sets success state and returns null', () async {
    final repo = _FakeCouponRepository();
    final container = _container(repo);

    final error = await container
        .read(couponProvider.notifier)
        .apply(code: 'SAVE10', orderId: 'o1');

    expect(error, isNull);
    expect(repo.redeemCalls, 1);
    expect(repo.lastCode, 'SAVE10');
    expect(repo.lastOrderId, 'o1');
    final state = container.read(couponProvider);
    expect(state.status, CouponStatus.success);
    expect(state.isApplied, isTrue);
    expect(state.redemption!.discountAmount, 250);
  });

  test('apply failure returns the P0001 message and does not throw', () async {
    final repo = _FakeCouponRepository(
      redeemError: const Failure(message: 'Coupon is not valid.'),
    );
    final container = _container(repo);

    final error = await container
        .read(couponProvider.notifier)
        .apply(code: 'BAD', orderId: 'o1');

    expect(error, 'Coupon is not valid.');
    final state = container.read(couponProvider);
    expect(state.status, CouponStatus.failure);
    expect(state.message, 'Coupon is not valid.');
  });
}
