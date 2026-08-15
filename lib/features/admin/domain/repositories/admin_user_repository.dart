import '../entities/admin_user.dart';
import '../entities/app_role.dart';

/// Contract for admin user & role management. Reads/writes rely on the admin
/// RLS arm (`has_role('admin')`); non-admins are denied server-side. Status /
/// soft-delete changes are additionally reserved to admins by the
/// profiles_admin_fields_guard trigger, and the last administrator cannot be
/// removed (profile_roles_last_admin_guard). Failures map to `Failure`.
abstract class AdminUserRepository {
  /// All users with their assigned roles, newest first.
  Future<List<AdminUser>> listUsers();

  /// Every role definition (for the role picker).
  Future<List<AppRole>> listRoles();

  /// Sets an account's status (`active` / `suspended` / `blocked`).
  Future<void> setStatus({required String profileId, required String status});

  /// Soft-deletes ([deleted] true) or restores a user account.
  Future<void> setDeleted({required String profileId, required bool deleted});

  /// Grants [roleId] to a user (idempotent under `UNIQUE(profile_id, role_id)`).
  Future<void> grantRole({required String profileId, required String roleId});

  /// Revokes [roleId] from a user. The server blocks removing the last admin.
  Future<void> revokeRole({required String profileId, required String roleId});
}
