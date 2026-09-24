import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/supabase/supabase_auth_service.dart';
import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/supabase/supabase_storage_service.dart';
import '../../../../core/utils/failure.dart';
import '../../../authentication/domain/validators/auth_validators.dart';
import '../../domain/entities/address.dart';
import '../../domain/entities/business_profile.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/seller_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../profile_failure_mapper.dart';

/// Supabase-backed [ProfileRepository].
///
/// Wraps the shared [SupabaseDatabaseService] / [SupabaseStorageService] and
/// relies entirely on the existing RLS policies — it never bypasses security.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({
    required SupabaseDatabaseService database,
    required SupabaseStorageService storage,
    required SupabaseAuthService authService,
  }) : _database = database,
       _storage = storage,
       _authService = authService;

  final SupabaseDatabaseService _database;
  final SupabaseStorageService _storage;
  final SupabaseAuthService _authService;

  static const String avatarBucket = 'avatars';
  static const String _profilesTable = 'profiles';
  static const String _addressesTable = 'addresses';
  static const String _businessTable = 'business_profiles';
  static const String _sellerTable = 'seller_profiles';

  /// Storage object path for a profile's avatar. A per-upload token in the
  /// filename makes the public URL change on every replacement, so clients
  /// (whose image cache keys on the URL) never keep showing the old avatar.
  static String avatarObjectPath(String profileId) =>
      '$profileId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

  // Profile ----------------------------------------------------------------

  @override
  Future<Profile?> getProfile() async {
    try {
      final userId = _requireUserId();
      final rows = await _database.select(
        table: _profilesTable,
        filters: {'user_id': userId},
      );
      if (rows.isEmpty) return null;
      return Profile.fromMap(rows.first);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<Profile> ensureProfile() async {
    try {
      final existing = await getProfile();
      if (existing != null) return existing;

      final user = _requireUser();
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final metaName = (metadata['full_name'] as String?)?.trim();
      final metaPhone = (metadata['phone'] as String?)?.trim();

      final fullName = (metaName != null && metaName.isNotEmpty)
          ? metaName
          : (user.email ?? 'New User');
      // Only carry over contact fields that pass the existing validators; the
      // user can complete the rest later from profile settings.
      final email = _isValid(AuthValidators.email(user.email))
          ? user.email
          : null;
      final phone =
          (metaPhone != null &&
              _isValid(AuthValidators.pakistanPhone(metaPhone)))
          ? metaPhone
          : null;

      return await createProfile(
        fullName: fullName,
        email: email,
        phone: phone,
      );
    } catch (error) {
      // Handle the race where the row was created concurrently (e.g. by the
      // handle_new_user trigger) between the existence check and the insert.
      final again = await getProfile();
      if (again != null) return again;
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<Profile> createProfile({
    required String fullName,
    String? email,
    String? phone,
  }) async {
    try {
      final userId = _requireUserId();
      _validateProfileFields(fullName: fullName, email: email, phone: phone);
      final row = await _database.insert(
        table: _profilesTable,
        values: {
          'user_id': userId,
          'full_name': fullName.trim(),
          if (email != null) 'email': email.trim(),
          if (phone != null) 'phone': phone.trim(),
        },
      );
      return Profile.fromMap(row);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<Profile> updateProfile({
    String? fullName,
    String? phone,
    String? email,
  }) async {
    try {
      final userId = _requireUserId();
      _validateProfileFields(fullName: fullName, email: email, phone: phone);
      final values = <String, dynamic>{
        if (fullName != null) 'full_name': fullName.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (email != null) 'email': email.trim(),
      };
      if (values.isEmpty) {
        final current = await getProfile();
        if (current == null) {
          throw const Failure(message: 'Profile not found.');
        }
        return current;
      }
      final row = await _database.update(
        table: _profilesTable,
        values: values,
        matchColumn: 'user_id',
        matchValue: userId,
      );
      return Profile.fromMap(row);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  // Avatar storage ---------------------------------------------------------

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final profile = await getProfile();
      if (profile == null) {
        throw const Failure(
          message: 'Complete your profile before uploading an avatar.',
        );
      }
      final path = avatarObjectPath(profile.id);

      // Delete the previous avatar before replacing it.
      final previous = profile.avatarPath;
      if (previous != null && previous.isNotEmpty) {
        await _storage.deleteImage(bucket: avatarBucket, path: previous);
      }

      await _storage.uploadImage(
        bucket: avatarBucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
        upsert: true,
      );

      await _database.update(
        table: _profilesTable,
        values: {'avatar_path': path},
        matchColumn: 'id',
        matchValue: profile.id,
      );

      return _storage.getPublicUrl(bucket: avatarBucket, path: path);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteAvatar() async {
    try {
      final profile = await getProfile();
      if (profile == null) return;
      final previous = profile.avatarPath;
      if (previous != null && previous.isNotEmpty) {
        await _storage.deleteImage(bucket: avatarBucket, path: previous);
      }
      await _database.update(
        table: _profilesTable,
        values: {'avatar_path': null},
        matchColumn: 'id',
        matchValue: profile.id,
      );
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  // Addresses --------------------------------------------------------------

  @override
  Future<List<Address>> getAddresses() async {
    try {
      final profileId = await _requireProfileId();
      final rows = await _database.select(
        table: _addressesTable,
        filters: {'profile_id': profileId},
      );
      final addresses = rows.map(Address.fromMap).toList()
        ..sort((a, b) {
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          final ac = a.createdAt;
          final bc = b.createdAt;
          if (ac == null || bc == null) return 0;
          return bc.compareTo(ac);
        });
      return addresses;
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<Address> addAddress({
    required String recipientName,
    required String phone,
    required String addressLine1,
    required String city,
    required String province,
    String addressType = 'shipping',
    String? label,
    String? addressLine2,
    String? area,
    String? postalCode,
    String country = 'Pakistan',
    bool isDefault = false,
  }) async {
    try {
      final profileId = await _requireProfileId();
      _validateRequired(recipientName, 'Recipient name');
      _validatePhone(phone);
      _validateRequired(addressLine1, 'Address');
      _validateRequired(city, 'City');
      _validateRequired(province, 'Province');
      _validateProvince(province);

      final row = await _database.insert(
        table: _addressesTable,
        values: {
          'profile_id': profileId,
          'address_type': addressType,
          'recipient_name': recipientName.trim(),
          'phone': _normalizePhone(phone),
          'address_line_1': addressLine1.trim(),
          'city': city.trim(),
          'province': province,
          'country': country,
          'is_default': isDefault,
          'label': ?label,
          'address_line_2': ?addressLine2,
          'area': ?area,
          'postal_code': ?postalCode,
        },
      );
      return Address.fromMap(row);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<Address> updateAddress({
    required String addressId,
    String? recipientName,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? area,
    String? city,
    String? province,
    String? postalCode,
    String? label,
    String? addressType,
    bool? isDefault,
  }) async {
    try {
      if (phone != null) _validatePhone(phone);
      if (province != null) _validateProvince(province);
      final values = <String, dynamic>{
        if (recipientName != null) 'recipient_name': recipientName.trim(),
        if (phone != null) 'phone': _normalizePhone(phone),
        if (addressLine1 != null) 'address_line_1': addressLine1.trim(),
        'address_line_2': ?addressLine2,
        'area': ?area,
        if (city != null) 'city': city.trim(),
        'province': ?province,
        'postal_code': ?postalCode,
        'label': ?label,
        'address_type': ?addressType,
        'is_default': ?isDefault,
      };
      if (values.isEmpty) {
        throw const Failure(message: 'No changes provided.');
      }
      final row = await _database.update(
        table: _addressesTable,
        values: values,
        matchColumn: 'id',
        matchValue: addressId,
      );
      return Address.fromMap(row);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteAddress({required String addressId}) async {
    try {
      await _database.delete(
        table: _addressesTable,
        matchColumn: 'id',
        matchValue: addressId,
      );
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<Address> setDefaultAddress({required String addressId}) async {
    try {
      final profileId = await _requireProfileId();
      final targetRows = await _database.select(
        table: _addressesTable,
        filters: {'id': addressId, 'profile_id': profileId},
      );
      if (targetRows.isEmpty) {
        throw const Failure(message: 'Address not found.');
      }
      final target = Address.fromMap(targetRows.first);

      // Clear the existing default of the same type to satisfy the single
      // default-per-type unique index, then mark the target as default.
      final currentDefaults = await _database.select(
        table: _addressesTable,
        filters: {
          'profile_id': profileId,
          'address_type': target.addressType,
          'is_default': true,
        },
      );
      for (final row in currentDefaults) {
        final id = row['id'] as String;
        if (id == addressId) continue;
        await _database.update(
          table: _addressesTable,
          values: {'is_default': false},
          matchColumn: 'id',
          matchValue: id,
        );
      }

      final updated = await _database.update(
        table: _addressesTable,
        values: {'is_default': true},
        matchColumn: 'id',
        matchValue: addressId,
      );
      return Address.fromMap(updated);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  // Business profile -------------------------------------------------------

  @override
  Future<BusinessProfile?> getBusinessProfile() async {
    try {
      final profileId = await _requireProfileId();
      final rows = await _database.select(
        table: _businessTable,
        filters: {'profile_id': profileId},
      );
      if (rows.isEmpty) return null;
      return BusinessProfile.fromMap(rows.first);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<BusinessProfile> createBusinessProfile({
    required String businessName,
    required String contactPerson,
    required String contactPhone,
    String? businessType,
    String? ntnNumber,
    String? strnNumber,
  }) async {
    try {
      final profileId = await _requireProfileId();
      _validateRequired(businessName, 'Business name');
      _validateRequired(contactPerson, 'Contact person');
      _validatePhone(contactPhone);

      final row = await _database.insert(
        table: _businessTable,
        values: {
          'profile_id': profileId,
          'business_name': businessName.trim(),
          'contact_person': contactPerson.trim(),
          'contact_phone': contactPhone.trim(),
          'business_type': ?businessType,
          'ntn_number': ?ntnNumber,
          'strn_number': ?strnNumber,
        },
      );
      return BusinessProfile.fromMap(row);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<BusinessProfile> updateBusinessProfile({
    String? businessName,
    String? contactPerson,
    String? contactPhone,
    String? businessType,
    String? ntnNumber,
    String? strnNumber,
  }) async {
    try {
      final profileId = await _requireProfileId();
      if (contactPhone != null) _validatePhone(contactPhone);
      final values = <String, dynamic>{
        if (businessName != null) 'business_name': businessName.trim(),
        if (contactPerson != null) 'contact_person': contactPerson.trim(),
        if (contactPhone != null) 'contact_phone': contactPhone.trim(),
        'business_type': ?businessType,
        'ntn_number': ?ntnNumber,
        'strn_number': ?strnNumber,
      };
      if (values.isEmpty) {
        throw const Failure(message: 'No changes provided.');
      }
      final row = await _database.update(
        table: _businessTable,
        values: values,
        matchColumn: 'profile_id',
        matchValue: profileId,
      );
      return BusinessProfile.fromMap(row);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  // Seller profile ---------------------------------------------------------

  @override
  Future<SellerProfile?> getSellerProfile() async {
    try {
      final profileId = await _requireProfileId();
      final rows = await _database.select(
        table: _sellerTable,
        filters: {'profile_id': profileId},
      );
      if (rows.isEmpty) return null;
      return SellerProfile.fromMap(rows.first);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<SellerProfile> createSellerProfile({
    required String storeName,
    required String slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
  }) async {
    try {
      final profileId = await _requireProfileId();
      _validateRequired(storeName, 'Store name');
      _validateRequired(slug, 'Store URL');

      final row = await _database.insert(
        table: _sellerTable,
        values: {
          'profile_id': profileId,
          'store_name': storeName.trim(),
          'slug': slug.trim(),
          'description': ?description,
          'city': ?city,
          'logo_url': ?logoUrl,
          'banner_url': ?bannerUrl,
        },
      );
      return SellerProfile.fromMap(row);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  @override
  Future<SellerProfile> updateSellerProfile({
    String? storeName,
    String? slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
    bool? isWholesaleEnabled,
  }) async {
    try {
      final profileId = await _requireProfileId();
      final values = <String, dynamic>{
        if (storeName != null) 'store_name': storeName.trim(),
        if (slug != null) 'slug': slug.trim(),
        'description': ?description,
        'city': ?city,
        'logo_url': ?logoUrl,
        'banner_url': ?bannerUrl,
        'is_wholesale_enabled': ?isWholesaleEnabled,
      };
      if (values.isEmpty) {
        throw const Failure(message: 'No changes provided.');
      }
      final row = await _database.update(
        table: _sellerTable,
        values: values,
        matchColumn: 'profile_id',
        matchValue: profileId,
      );
      return SellerProfile.fromMap(row);
    } catch (error) {
      throw ProfileFailureMapper.map(error);
    }
  }

  // Helpers ----------------------------------------------------------------

  String _requireUserId() => _requireUser().id;

  supabase.User _requireUser() {
    final user = _authService.currentUser;
    if (user == null) {
      throw const Failure(message: 'Authentication required.');
    }
    return user;
  }

  Future<String> _requireProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) {
      return result;
    }
    throw const Failure(
      message: 'No profile found. Please complete your profile first.',
    );
  }

  void _validateProfileFields({
    String? fullName,
    String? email,
    String? phone,
  }) {
    if (fullName != null) _throwIfInvalid(AuthValidators.fullName(fullName));
    if (email != null) _throwIfInvalid(AuthValidators.email(email));
    if (phone != null) _throwIfInvalid(AuthValidators.pakistanPhone(phone));
  }

  void _validateRequired(String value, String fieldName) {
    _throwIfInvalid(AuthValidators.required(value, fieldName: fieldName));
  }

  void _validatePhone(String phone) {
    _throwIfInvalid(AuthValidators.pakistanPhone(phone));
  }

  void _throwIfInvalid(String? validationError) {
    if (validationError != null) {
      throw Failure(message: validationError);
    }
  }

  /// Strips spaces/dashes so a phone that passed [AuthValidators.pakistanPhone]
  /// (which normalizes before matching) also satisfies the DB's strict
  /// `addresses_phone_check` regex, which allows digits only.
  String _normalizePhone(String phone) =>
      phone.trim().replaceAll(RegExp(r'[\s-]'), '');

  /// Guards the `addresses_province_check` constraint with a clear message
  /// rather than a generic backend error.
  void _validateProvince(String province) {
    _throwIfInvalid(
      kPakistanProvinces.contains(province)
          ? null
          : 'Please select a valid province.',
    );
  }

  bool _isValid(String? validationError) => validationError == null;
}
