import 'package:aurivo/features/profile/domain/entities/business_profile.dart';
import 'package:aurivo/features/profile/domain/repositories/profile_repository.dart';
import 'package:aurivo/features/profile/presentation/business_account_page.dart';
import 'package:aurivo/features/profile/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

BusinessProfile _business(String status) => BusinessProfile(
  id: 'b1',
  profileId: 'p1',
  businessName: 'Alif Traders',
  contactPerson: 'Ali',
  contactPhone: '03001234567',
  verificationStatus: status,
);

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo({this.business});
  final BusinessProfile? business;

  @override
  Future<BusinessProfile?> getBusinessProfile() async => business;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(ProfileRepository repo) => ProviderScope(
  overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: BusinessAccountPage()),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows the registration form when no business exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_FakeProfileRepo()));
    await _settle(tester);

    expect(find.text('Register your business'), findsOneWidget);
    expect(find.text('Submit for verification'), findsOneWidget);
  });

  testWidgets('shows the status with a badge when a business exists', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeProfileRepo(business: _business('verified'))));
    await _settle(tester);

    expect(find.text('Alif Traders'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.textContaining('unlocked'), findsOneWidget);
    // No registration form when already registered.
    expect(find.text('Submit for verification'), findsNothing);
  });

  testWidgets('pending business shows a Pending badge and review hint', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeProfileRepo(business: _business('pending'))));
    await _settle(tester);

    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('reviewing'), findsOneWidget);
  });
}
