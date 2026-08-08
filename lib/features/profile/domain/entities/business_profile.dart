import 'entity_parsing.dart';

/// B2B buyer profile for wholesale access (`public.business_profiles`).
class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.profileId,
    required this.businessName,
    this.businessType,
    this.ntnNumber,
    this.strnNumber,
    required this.contactPerson,
    required this.contactPhone,
    this.verificationStatus = 'pending',
    this.documents = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String profileId;
  final String businessName;
  final String? businessType;
  final String? ntnNumber;
  final String? strnNumber;
  final String contactPerson;
  final String contactPhone;
  final String verificationStatus;
  final List<dynamic> documents;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      businessName: map['business_name'] as String,
      businessType: map['business_type'] as String?,
      ntnNumber: map['ntn_number'] as String?,
      strnNumber: map['strn_number'] as String?,
      contactPerson: map['contact_person'] as String,
      contactPhone: map['contact_phone'] as String,
      verificationStatus: map['verification_status'] as String? ?? 'pending',
      documents: map['documents'] as List<dynamic>? ?? const [],
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
