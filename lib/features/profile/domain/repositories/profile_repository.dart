import 'dart:typed_data';

import '../entities/address.dart';
import '../entities/business_profile.dart';
import '../entities/profile.dart';
import '../entities/seller_profile.dart';

/// Contract for profile, address, business, and seller-profile data.
///
/// Implementations must never surface raw Supabase exceptions; all failures are
/// mapped to the shared [Failure] type.
abstract class ProfileRepository {
  // Profile ----------------------------------------------------------------
  Future<Profile?> getProfile();

  /// Returns the current user's profile, creating one from the auth user if it
  /// does not exist yet. Idempotent — never creates duplicates.
  Future<Profile> ensureProfile();

  Future<Profile> createProfile({
    required String fullName,
    String? email,
    String? phone,
  });

  Future<Profile> updateProfile({
    String? fullName,
    String? phone,
    String? email,
  });

  /// Uploads/replaces the avatar and returns its public URL.
  Future<String> uploadAvatar({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });

  Future<void> deleteAvatar();

  // Addresses --------------------------------------------------------------
  Future<List<Address>> getAddresses();

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
  });

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
  });

  Future<void> deleteAddress({required String addressId});

  Future<Address> setDefaultAddress({required String addressId});

  // Business profile -------------------------------------------------------
  Future<BusinessProfile?> getBusinessProfile();

  Future<BusinessProfile> createBusinessProfile({
    required String businessName,
    required String contactPerson,
    required String contactPhone,
    String? businessType,
    String? ntnNumber,
    String? strnNumber,
  });

  Future<BusinessProfile> updateBusinessProfile({
    String? businessName,
    String? contactPerson,
    String? contactPhone,
    String? businessType,
    String? ntnNumber,
    String? strnNumber,
  });

  // Seller profile ---------------------------------------------------------
  Future<SellerProfile?> getSellerProfile();

  Future<SellerProfile> createSellerProfile({
    required String storeName,
    required String slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
  });

  Future<SellerProfile> updateSellerProfile({
    String? storeName,
    String? slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
    bool? isWholesaleEnabled,
  });
}
