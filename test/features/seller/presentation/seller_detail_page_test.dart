import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_repository.dart';
import 'package:aurivo/features/seller/domain/entities/seller_review.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_review_repository.dart';
import 'package:aurivo/features/seller/presentation/seller_detail_page.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart';
import 'package:aurivo/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:aurivo/features/wishlist/providers/wishlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerProfile _seller() => const SellerProfile(
  id: 's1',
  profileId: 'p1',
  storeName: 'Gold House',
  slug: 'gold-house',
  verificationStatus: 'verified',
);

class _FakeSellerRepository implements SellerRepository {
  @override
  Future<SellerProfile?> getSellerBySlug(String slug) async => _seller();

  @override
  Future<SellerProfile?> getSellerById(String id) async => _seller();

  @override
  Future<List<SellerProfile>> getVerifiedSellers({
    int limit = 20,
    int offset = 0,
  }) async => [_seller()];

  @override
  Future<List<Product>> getSellerProducts(
    String sellerId, {
    int limit = 20,
    int offset = 0,
  }) async => const [];
}

class _FakeReviewRepository implements SellerReviewRepository {
  @override
  Future<List<SellerReview>> getApprovedReviews(
    String sellerProfileId, {
    int limit = 50,
    int offset = 0,
  }) async => const [];

  @override
  Future<SellerReview?> getMyReview(String sellerProfileId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubWishlistRepository implements WishlistRepository {
  @override
  Future<Set<String>> getWishlistedProductIds() async => <String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthedSession extends SessionNotifier {
  _AuthedSession()
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      ) {
    state = const SessionState(status: SessionStatus.authenticated);
  }
}

Widget _app(List<Override> extra) => ProviderScope(
  overrides: [
    sellerRepositoryProvider.overrideWithValue(_FakeSellerRepository()),
    sellerReviewRepositoryProvider.overrideWithValue(_FakeReviewRepository()),
    ...extra,
  ],
  child: const MaterialApp(home: SellerDetailPage(slug: 'gold-house')),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(); // post-frame load starts
  await tester.pump(); // async result
  await tester.pump(); // rebuild
}

void main() {
  testWidgets('shows Message + Request Quote for a signed-in buyer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        sessionProvider.overrideWith((ref) => _AuthedSession()),
        wishlistRepositoryProvider.overrideWithValue(_StubWishlistRepository()),
      ]),
    );
    await _settle(tester);

    expect(find.text('Gold House'), findsWidgets); // storefront loaded
    expect(find.text('Request Quote'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
  });

  testWidgets('hides both seller CTAs for a signed-out buyer', (tester) async {
    await tester.pumpWidget(_app(const []));
    await _settle(tester);

    expect(find.text('Gold House'), findsWidgets); // storefront still loads
    expect(find.text('Request Quote'), findsNothing);
    expect(find.text('Message'), findsNothing);
  });
}
