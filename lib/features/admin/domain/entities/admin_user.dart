import '../../../../core/utils/db_parsing.dart';
import '../../../profile/domain/entities/profile.dart';
import 'app_role.dart';

/// A user as seen by the admin console: their [Profile], assigned [roles], and
/// soft-deletion state (the buyer `Profile` entity omits `deleted_at`).
class AdminUser {
  const AdminUser({
    required this.profile,
    this.roles = const [],
    this.deletedAt,
  });

  final Profile profile;
  final List<AppRole> roles;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool hasRole(String name) => roles.any((r) => r.name == name);
  List<String> get roleNames => roles.map((r) => r.name).toList();

  factory AdminUser.fromParts(
    Map<String, dynamic> profileMap,
    List<AppRole> roles,
  ) {
    return AdminUser(
      profile: Profile.fromMap(profileMap),
      roles: roles,
      deletedAt: parseTimestamp(profileMap['deleted_at']),
    );
  }
}
