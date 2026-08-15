import 'package:aurivo/features/admin/domain/entities/admin_user.dart';
import 'package:aurivo/features/admin/domain/entities/app_role.dart';
import 'package:aurivo/features/admin/domain/repositories/admin_user_repository.dart';
import 'package:aurivo/features/admin/presentation/admin_user_detail_page.dart';
import 'package:aurivo/features/admin/presentation/admin_users_page.dart';
import 'package:aurivo/features/admin/providers/admin_user_providers.dart';
import 'package:aurivo/features/profile/domain/entities/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _adminRole = AppRole(id: 'r-admin', name: 'admin');
const _sellerRole = AppRole(id: 'r-seller', name: 'seller');

AdminUser _user(
  String id, {
  String status = 'active',
  List<AppRole> roles = const [],
}) => AdminUser(
  profile: Profile(
    id: id,
    userId: 'u-$id',
    fullName: 'User $id',
    email: '$id@test.local',
    status: status,
  ),
  roles: roles,
);

class _FakeRepo implements AdminUserRepository {
  _FakeRepo(this.users);
  final List<AdminUser> users;
  final List<String> log = [];

  @override
  Future<List<AdminUser>> listUsers() async => users;

  @override
  Future<List<AppRole>> listRoles() async => const [_adminRole, _sellerRole];

  @override
  Future<void> setStatus({
    required String profileId,
    required String status,
  }) async => log.add('status:$profileId:$status');

  @override
  Future<void> setDeleted({
    required String profileId,
    required bool deleted,
  }) async => log.add('deleted:$profileId:$deleted');

  @override
  Future<void> grantRole({
    required String profileId,
    required String roleId,
  }) async => log.add('grant:$profileId:$roleId');

  @override
  Future<void> revokeRole({
    required String profileId,
    required String roleId,
  }) async => log.add('revoke:$profileId:$roleId');
}

// Self-detection uses sessionProvider.user?.id, which is null in tests (no
// Supabase session), so it never matches a profile's userId — exercising the
// non-self guard paths (last-admin, and normal grant/revoke).
Widget _wrap(_FakeRepo repo, Widget page) => ProviderScope(
  overrides: [adminUserRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(home: page),
);

void main() {
  testWidgets('user list shows name, status and roles', (tester) async {
    final repo = _FakeRepo([
      _user('1', roles: const [_adminRole]),
      _user('2', status: 'suspended', roles: const [_sellerRole]),
    ]);
    await tester.pumpWidget(_wrap(repo, const AdminUsersPage()));
    await tester.pumpAndSettle();

    expect(find.text('User 1'), findsOneWidget);
    expect(find.text('User 2'), findsOneWidget);
    expect(find.text('suspended'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);
  });

  testWidgets('detail suspends a user', (tester) async {
    final repo = _FakeRepo([_user('1', roles: const [_sellerRole])]);
    await tester.pumpWidget(
      _wrap(repo, const AdminUserDetailPage(profileId: '1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('suspended'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('status:1:suspended'));
  });

  testWidgets('cannot revoke the last admin (client guard)', (tester) async {
    // Only one admin in the system → revoking it must be blocked client-side.
    final repo = _FakeRepo([_user('1', roles: const [_adminRole])]);
    await tester.pumpWidget(
      _wrap(repo, const AdminUserDetailPage(profileId: '1')),
    );
    await tester.pumpAndSettle();

    // Tap the selected 'admin' role chip to attempt a revoke.
    await tester.tap(find.text('admin'));
    await tester.pumpAndSettle();

    expect(repo.log, isNot(contains('revoke:1:r-admin')));
    expect(find.textContaining('At least one administrator'), findsOneWidget);
  });

  testWidgets('can revoke admin when another admin exists', (tester) async {
    final repo = _FakeRepo([
      _user('1', roles: const [_adminRole]),
      _user('2', roles: const [_adminRole]),
    ]);
    await tester.pumpWidget(
      _wrap(repo, const AdminUserDetailPage(profileId: '1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('admin'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('revoke:1:r-admin'));
  });
}
