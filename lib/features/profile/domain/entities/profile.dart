import 'entity_parsing.dart';

/// Application profile for a Supabase Auth user (`public.profiles`).
class Profile {
  const Profile({
    required this.id,
    required this.userId,
    required this.fullName,
    this.email,
    this.phone,
    this.avatarPath,
    this.status = 'active',
    this.isPhoneVerified = false,
    this.isEmailVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarPath;
  final String status;
  final bool isPhoneVerified;
  final bool isEmailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      avatarPath: map['avatar_path'] as String?,
      status: map['status'] as String? ?? 'active',
      isPhoneVerified: map['is_phone_verified'] as bool? ?? false,
      isEmailVerified: map['is_email_verified'] as bool? ?? false,
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
