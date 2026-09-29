import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/profile/domain/entities/business_profile.dart';
import 'package:aurivo/features/profile/domain/repositories/profile_repository.dart';
import 'package:aurivo/features/profile/providers/profile_providers.dart';
import 'package:aurivo/features/wholesale/presentation/wholesale_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

BusinessProfile _business(String status) => BusinessProfile(
  id: 'b1',
  profileId: 'p1',
  businessName: 'Nex Jewel',
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

Future<bool?> _run(WidgetTester tester, ProfileRepository repo) async {
  bool? result;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await ensureVerifiedBusiness(context, ref);
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.businessAccount,
        builder: (_, _) => const Scaffold(body: Text('BUSINESS')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('verified business passes the gate without navigating', (
    tester,
  ) async {
    final result = await _run(
      tester,
      _FakeProfileRepo(business: _business('verified')),
    );
    expect(result, isTrue);
    expect(find.text('BUSINESS'), findsNothing);
  });

  testWidgets('no business is blocked and routed to the business account', (
    tester,
  ) async {
    final result = await _run(tester, _FakeProfileRepo());
    expect(result, isFalse);
    expect(find.text('BUSINESS'), findsOneWidget);
  });

  testWidgets('pending business is blocked and routed to the business account', (
    tester,
  ) async {
    final result = await _run(
      tester,
      _FakeProfileRepo(business: _business('pending')),
    );
    expect(result, isFalse);
    expect(find.text('BUSINESS'), findsOneWidget);
  });
}
