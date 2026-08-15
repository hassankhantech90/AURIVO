import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../domain/entities/admin_user.dart';
import '../../domain/entities/app_role.dart';
import '../../domain/repositories/admin_user_repository.dart';
import '../admin_failure_mapper.dart';

/// Supabase-backed [AdminUserRepository]. Uses the admin RLS arm; never bypasses
/// security. Status/soft-delete and last-admin protection are enforced by the
/// database guard triggers (migration 13).
class SupabaseAdminUserRepository implements AdminUserRepository {
  SupabaseAdminUserRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const _profiles = 'profiles';
  static const _roles = 'roles';
  static const _profileRoles = 'profile_roles';

  @override
  Future<List<AppRole>> listRoles() async {
    try {
      final rows = await _database.list(table: _roles, orderBy: 'name');
      return rows.map(AppRole.fromMap).toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<List<AdminUser>> listUsers() async {
    try {
      final profileRows = await _database.list(
        table: _profiles,
        orderBy: 'created_at',
        ascending: false,
      );
      final roleRows = await _database.list(table: _roles);
      final assignmentRows = await _database.list(table: _profileRoles);

      final rolesById = {
        for (final r in roleRows) r['id'] as String: AppRole.fromMap(r),
      };
      final rolesByProfile = <String, List<AppRole>>{};
      for (final a in assignmentRows) {
        final role = rolesById[a['role_id'] as String];
        if (role == null) continue;
        (rolesByProfile[a['profile_id'] as String] ??= []).add(role);
      }

      return profileRows
          .map(
            (p) => AdminUser.fromParts(
              p,
              rolesByProfile[p['id'] as String] ?? const [],
            ),
          )
          .toList();
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> setStatus({
    required String profileId,
    required String status,
  }) async {
    try {
      await _database.update(
        table: _profiles,
        values: {'status': status},
        matchColumn: 'id',
        matchValue: profileId,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> setDeleted({
    required String profileId,
    required bool deleted,
  }) async {
    try {
      await _database.update(
        table: _profiles,
        values: {
          'deleted_at': deleted ? DateTime.now().toUtc().toIso8601String() : null,
        },
        matchColumn: 'id',
        matchValue: profileId,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> grantRole({
    required String profileId,
    required String roleId,
  }) async {
    try {
      await _database.insert(
        table: _profileRoles,
        values: {'profile_id': profileId, 'role_id': roleId},
      );
    } on ex.AppSupabaseException catch (error) {
      // Already granted — UNIQUE(profile_id, role_id); treat as success.
      if (error.code == '23505') return;
      throw AdminFailureMapper.map(error);
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }

  @override
  Future<void> revokeRole({
    required String profileId,
    required String roleId,
  }) async {
    try {
      final rows = await _database.list(
        table: _profileRoles,
        filters: {'profile_id': profileId, 'role_id': roleId},
        limit: 1,
      );
      if (rows.isEmpty) return;
      await _database.delete(
        table: _profileRoles,
        matchColumn: 'id',
        matchValue: rows.first['id'] as Object,
      );
    } catch (error) {
      throw AdminFailureMapper.map(error);
    }
  }
}
