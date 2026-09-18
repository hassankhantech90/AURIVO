import 'entity_parsing.dart';

/// Provinces/territories the backend accepts for `addresses.province`
/// (must match the `addresses_province_check` constraint exactly).
const List<String> kPakistanProvinces = [
  'Punjab',
  'Sindh',
  'Khyber Pakhtunkhwa',
  'Balochistan',
  'Islamabad Capital Territory',
  'Gilgit-Baltistan',
  'Azad Jammu and Kashmir',
];

/// Billing / shipping / business address for a profile (`public.addresses`).
class Address {
  const Address({
    required this.id,
    required this.profileId,
    required this.addressType,
    this.label,
    required this.recipientName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2,
    this.area,
    required this.city,
    required this.province,
    this.postalCode,
    this.country = 'Pakistan',
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String profileId;
  final String addressType;
  final String? label;
  final String recipientName;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String? area;
  final String city;
  final String province;
  final String? postalCode;
  final String country;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      addressType: map['address_type'] as String? ?? 'shipping',
      label: map['label'] as String?,
      recipientName: map['recipient_name'] as String,
      phone: map['phone'] as String,
      addressLine1: map['address_line_1'] as String,
      addressLine2: map['address_line_2'] as String?,
      area: map['area'] as String?,
      city: map['city'] as String,
      province: map['province'] as String,
      postalCode: map['postal_code'] as String?,
      country: map['country'] as String? ?? 'Pakistan',
      isDefault: map['is_default'] as bool? ?? false,
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
}
