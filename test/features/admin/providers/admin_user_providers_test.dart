import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/domain/entities/admin_user.dart';
import 'package:aurivo/features/admin/domain/entities/app_role.dart';
import 'package:aurivo/features/admin/domain/repositories/admin_user_repository.dart';
import 'package:aurivo/features/admin/providers/admin_user_providers.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart'
    show AdminStatus;
import 'package:aurivo/features/profile/domain/entities/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdminUser _user(String id, {List<AppRole> roles = const []}) => AdminUser(
  profile: Profile(id: id, userId: 'u-$id', fullName: 'User $id'),
  roles: roles,
);

class _FakeRepo implements AdminUserRepository {
  List<AdminUser> users = [_user('1')];
  final List<String> log = [];

  @override
  Future<List<AdminUser>> listUsers() async => users;

  @override
  Future<List<AppRole>> listRoles() async =>
      const [AppRole(id: 'r-seller', name: 'seller')];

  @override
  Future<void> setStatus({
    required String profileId,
    required String status,
  }) async {
    log.add('status:$profileId:$status');
  }

  @override
  Future<void> setDeleted({
    required String profileId,
    required bool deleted,
  }) async {
    log.add('deleted:$profileId:$deleted');
  }

  @override
  Future<void> grantRole({
    required String profileId,
    required String roleId,
  }) async {
    log.add('grant:$profileId:$roleId');
  }

  @override
  Future<void> revokeRole({
    required String profileId,
    required String roleId,
  }) async {
    log.add('revoke:$profileId:$roleId');
  }
}

class _ThrowingRepo extends _FakeRepo {
  @override
  Future<void> setStatus({
    required String profileId,
    required String status,
  }) async => throw const Failure(message: 'not permitted');
}

ProviderContainer _container(AdminUserRepository repo) {
  final container = ProviderContainer(
    overrides: [adminUserRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load exposes users; roles provider works', () async {
    final container = _container(_FakeRepo());
    await container.read(adminUsersProvider.notifier).load();
    expect(container.read(adminUsersProvider).status, AdminStatus.success);
    final roles = await container.read(adminRolesProvider.future);
    expect(roles.single.name, 'seller');
  });

  test('status / delete / grant / revoke call through and reload', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final n = container.read(adminUsersProvider.notifier);
    await n.load();

    expect(await n.setStatus('1', 'suspended'), isNull);
    expect(await n.setDeleted('1', true), isNull);
    expect(await n.grantRole('1', 'r-seller'), isNull);
    expect(await n.revokeRole('1', 'r-seller'), isNull);

    expect(repo.log, [
      'status:1:suspended',
      'deleted:1:true',
      'grant:1:r-seller',
      'revoke:1:r-seller',
    ]);
  });

  test('surfaces the error message on failure', () async {
    final container = _container(_ThrowingRepo());
    final err = await container
        .read(adminUsersProvider.notifier)
        .setStatus('1', 'suspended');
    expect(err, contains('not permitted'));
  });
}
