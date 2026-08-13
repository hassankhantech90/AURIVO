import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/profile/domain/repositories/profile_repository.dart';
import 'package:aurivo/features/profile/providers/profile_providers.dart';
import 'package:aurivo/features/seller/presentation/store_settings_page.dart';
import 'package:aurivo/shared/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this._store);
  SellerProfile _store;

  int updateCalls = 0;
  Map<String, dynamic>? lastUpdateArgs;

  @override
  Future<SellerProfile?> getSellerProfile() async => _store;

  @override
  Future<SellerProfile> updateSellerProfile({
    String? storeName,
    String? slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
    bool? isWholesaleEnabled,
  }) async {
    updateCalls++;
    lastUpdateArgs = {
      'storeName': storeName,
      'slug': slug,
      'isWholesaleEnabled': isWholesaleEnabled,
    };
    _store = SellerProfile(
      id: _store.id,
      profileId: _store.profileId,
      storeName: storeName ?? _store.storeName,
      slug: slug ?? _store.slug,
      isWholesaleEnabled: isWholesaleEnabled ?? _store.isWholesaleEnabled,
    );
    return _store;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SellerProfile _store({String status = 'pending', bool wholesale = false}) =>
    SellerProfile(
      id: 'sp1',
      profileId: 'p1',
      storeName: 'Zainab Jewellers',
      slug: 'zainab-jewellers',
      verificationStatus: status,
      isWholesaleEnabled: wholesale,
    );

Widget _wrap(ProfileRepository repo) => ProviderScope(
  overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: StoreSettingsPage()),
);

void main() {
  testWidgets('hydrates the form from the loaded store', (tester) async {
    await tester.pumpWidget(_wrap(_FakeProfileRepository(_store())));
    await tester.pumpAndSettle();

    expect(find.text('Pending'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Zainab Jewellers'), findsOneWidget);
  });

  testWidgets('shows a Verified badge for verified stores', (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeProfileRepository(_store(status: 'verified'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('saves edits through updateSellerProfile', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeProfileRepository(_store());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'Zainab Fine Jewellery',
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(LoadingButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastUpdateArgs!['storeName'], 'Zainab Fine Jewellery');
    expect(repo.lastUpdateArgs!['isWholesaleEnabled'], isTrue);
  });
}
