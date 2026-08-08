import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/supabase/supabase_storage_service.dart';
import '../data/repositories/supabase_profile_repository.dart';
import '../domain/entities/address.dart';
import '../domain/entities/business_profile.dart';
import '../domain/entities/profile.dart';
import '../domain/entities/seller_profile.dart';
import '../domain/repositories/profile_repository.dart';

/// Repository binding for the profile module.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  const service = SupabaseService();
  return SupabaseProfileRepository(
    database: const SupabaseDatabaseService(supabaseService: service),
    storage: const SupabaseStorageService(supabaseService: service),
    authService: const SupabaseAuthService(supabaseService: service),
  );
});

/// Status for profile-module data views, mirroring the auth module style.
enum ProfileViewStatus { initial, loading, success, failure }

/// Generic state container for a single profile-module resource.
class ProfileDataState<T> {
  const ProfileDataState({
    this.status = ProfileViewStatus.initial,
    this.data,
    this.message,
  });

  final ProfileViewStatus status;
  final T? data;
  final String? message;

  bool get isLoading => status == ProfileViewStatus.loading;

  ProfileDataState<T> copyWith({
    ProfileViewStatus? status,
    T? data,
    String? message,
    bool clearMessage = false,
  }) {
    return ProfileDataState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// Shared run helper that maps actions into loading/success/failure states.
class _Runner<T> {
  _Runner(this._read, this._write);

  final ProfileDataState<T> Function() _read;
  final void Function(ProfileDataState<T>) _write;

  Future<void> run(Future<T> Function() action) async {
    _write(
      _read().copyWith(status: ProfileViewStatus.loading, clearMessage: true),
    );
    try {
      final data = await action();
      _write(
        ProfileDataState<T>(status: ProfileViewStatus.success, data: data),
      );
    } catch (error) {
      _write(
        _read().copyWith(
          status: ProfileViewStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }
}

// Profile --------------------------------------------------------------------

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileDataState<Profile>>((ref) {
      return ProfileNotifier(ref.watch(profileRepositoryProvider));
    });

class ProfileNotifier extends StateNotifier<ProfileDataState<Profile>> {
  ProfileNotifier(this._repository) : super(const ProfileDataState<Profile>()) {
    _runner = _Runner<Profile>(() => state, (value) => state = value);
  }

  final ProfileRepository _repository;
  late final _Runner<Profile> _runner;

  /// Loads the profile, creating it automatically if it does not exist.
  Future<void> load() => _runner.run(_repository.ensureProfile);

  Future<void> updateProfile({String? fullName, String? phone, String? email}) {
    return _runner.run(
      () => _repository.updateProfile(
        fullName: fullName,
        phone: phone,
        email: email,
      ),
    );
  }

  Future<void> uploadAvatar(Uint8List bytes) {
    return _runner.run(() async {
      await _repository.uploadAvatar(bytes: bytes);
      return await _repository.ensureProfile();
    });
  }

  Future<void> deleteAvatar() {
    return _runner.run(() async {
      await _repository.deleteAvatar();
      return await _repository.ensureProfile();
    });
  }
}

// Addresses ------------------------------------------------------------------

final addressesProvider =
    StateNotifierProvider<AddressesNotifier, ProfileDataState<List<Address>>>((
      ref,
    ) {
      return AddressesNotifier(ref.watch(profileRepositoryProvider));
    });

class AddressesNotifier extends StateNotifier<ProfileDataState<List<Address>>> {
  AddressesNotifier(this._repository)
    : super(const ProfileDataState<List<Address>>()) {
    _runner = _Runner<List<Address>>(() => state, (value) => state = value);
  }

  final ProfileRepository _repository;
  late final _Runner<List<Address>> _runner;

  Future<void> load() => _runner.run(_repository.getAddresses);

  Future<void> addAddress({
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
  }) {
    return _runner.run(() async {
      await _repository.addAddress(
        recipientName: recipientName,
        phone: phone,
        addressLine1: addressLine1,
        city: city,
        province: province,
        addressType: addressType,
        label: label,
        addressLine2: addressLine2,
        area: area,
        postalCode: postalCode,
        country: country,
        isDefault: isDefault,
      );
      return await _repository.getAddresses();
    });
  }

  Future<void> updateAddress({
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
  }) {
    return _runner.run(() async {
      await _repository.updateAddress(
        addressId: addressId,
        recipientName: recipientName,
        phone: phone,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        area: area,
        city: city,
        province: province,
        postalCode: postalCode,
        label: label,
        addressType: addressType,
        isDefault: isDefault,
      );
      return await _repository.getAddresses();
    });
  }

  Future<void> deleteAddress(String addressId) {
    return _runner.run(() async {
      await _repository.deleteAddress(addressId: addressId);
      return await _repository.getAddresses();
    });
  }

  Future<void> setDefaultAddress(String addressId) {
    return _runner.run(() async {
      await _repository.setDefaultAddress(addressId: addressId);
      return await _repository.getAddresses();
    });
  }
}

// Business profile -----------------------------------------------------------

final businessProfileProvider =
    StateNotifierProvider<
      BusinessProfileNotifier,
      ProfileDataState<BusinessProfile>
    >((ref) {
      return BusinessProfileNotifier(ref.watch(profileRepositoryProvider));
    });

class BusinessProfileNotifier
    extends StateNotifier<ProfileDataState<BusinessProfile>> {
  BusinessProfileNotifier(this._repository)
    : super(const ProfileDataState<BusinessProfile>()) {
    _runner = _Runner<BusinessProfile>(() => state, (value) => state = value);
  }

  final ProfileRepository _repository;
  late final _Runner<BusinessProfile> _runner;

  Future<void> load() {
    return _runner.run(() async {
      final profile = await _repository.getBusinessProfile();
      if (profile == null) {
        throw const _NotFound('No business profile yet.');
      }
      return profile;
    });
  }

  Future<void> createBusinessProfile({
    required String businessName,
    required String contactPerson,
    required String contactPhone,
    String? businessType,
    String? ntnNumber,
    String? strnNumber,
  }) {
    return _runner.run(
      () => _repository.createBusinessProfile(
        businessName: businessName,
        contactPerson: contactPerson,
        contactPhone: contactPhone,
        businessType: businessType,
        ntnNumber: ntnNumber,
        strnNumber: strnNumber,
      ),
    );
  }

  Future<void> updateBusinessProfile({
    String? businessName,
    String? contactPerson,
    String? contactPhone,
    String? businessType,
    String? ntnNumber,
    String? strnNumber,
  }) {
    return _runner.run(
      () => _repository.updateBusinessProfile(
        businessName: businessName,
        contactPerson: contactPerson,
        contactPhone: contactPhone,
        businessType: businessType,
        ntnNumber: ntnNumber,
        strnNumber: strnNumber,
      ),
    );
  }
}

// Seller profile -------------------------------------------------------------

final sellerProfileProvider =
    StateNotifierProvider<
      SellerProfileNotifier,
      ProfileDataState<SellerProfile>
    >((ref) {
      return SellerProfileNotifier(ref.watch(profileRepositoryProvider));
    });

class SellerProfileNotifier
    extends StateNotifier<ProfileDataState<SellerProfile>> {
  SellerProfileNotifier(this._repository)
    : super(const ProfileDataState<SellerProfile>()) {
    _runner = _Runner<SellerProfile>(() => state, (value) => state = value);
  }

  final ProfileRepository _repository;
  late final _Runner<SellerProfile> _runner;

  Future<void> load() {
    return _runner.run(() async {
      final profile = await _repository.getSellerProfile();
      if (profile == null) {
        throw const _NotFound('No seller profile yet.');
      }
      return profile;
    });
  }

  Future<void> createSellerProfile({
    required String storeName,
    required String slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
  }) {
    return _runner.run(
      () => _repository.createSellerProfile(
        storeName: storeName,
        slug: slug,
        description: description,
        city: city,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
      ),
    );
  }

  Future<void> updateSellerProfile({
    String? storeName,
    String? slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
    bool? isWholesaleEnabled,
  }) {
    return _runner.run(
      () => _repository.updateSellerProfile(
        storeName: storeName,
        slug: slug,
        description: description,
        city: city,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
        isWholesaleEnabled: isWholesaleEnabled,
      ),
    );
  }
}

/// Internal marker for "no row yet" so the notifier can show an empty state
/// without surfacing it as an error condition to callers.
class _NotFound implements Exception {
  const _NotFound(this.message);
  final String message;
  @override
  String toString() => message;
}
