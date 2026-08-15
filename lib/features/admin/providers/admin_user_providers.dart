import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/repositories/supabase_admin_user_repository.dart';
import '../domain/entities/admin_user.dart';
import '../domain/entities/app_role.dart';
import '../domain/repositories/admin_user_repository.dart';
import 'admin_providers.dart' show AdminListState, AdminStatus;

/// Repository binding (lazy service — stays test-safe without an initialized
/// Supabase client).
final adminUserRepositoryProvider = Provider<AdminUserRepository>((ref) {
  return SupabaseAdminUserRepository(
    database: const SupabaseDatabaseService(supabaseService: SupabaseService()),
  );
});

/// All role definitions (for the role picker).
final adminRolesProvider = FutureProvider<List<AppRole>>((ref) {
  return ref.watch(adminUserRepositoryProvider).listRoles();
});

final adminUsersProvider =
    StateNotifierProvider<AdminUsersNotifier, AdminListState<AdminUser>>((ref) {
      return AdminUsersNotifier(ref.watch(adminUserRepositoryProvider));
    });

class AdminUsersNotifier extends StateNotifier<AdminListState<AdminUser>> {
  AdminUsersNotifier(this._repository)
    : super(const AdminListState<AdminUser>());

  final AdminUserRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: AdminStatus.loading, clearMessage: true);
    try {
      state = AdminListState(
        status: AdminStatus.success,
        data: await _repository.listUsers(),
      );
    } catch (error) {
      state = state.copyWith(
        status: AdminStatus.failure,
        message: error.toString(),
      );
    }
  }

  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> setStatus(String profileId, String status) =>
      _run(() => _repository.setStatus(profileId: profileId, status: status));

  Future<String?> setDeleted(String profileId, bool deleted) =>
      _run(() => _repository.setDeleted(profileId: profileId, deleted: deleted));

  Future<String?> grantRole(String profileId, String roleId) =>
      _run(() => _repository.grantRole(profileId: profileId, roleId: roleId));

  Future<String?> revokeRole(String profileId, String roleId) =>
      _run(() => _repository.revokeRole(profileId: profileId, roleId: roleId));
}
