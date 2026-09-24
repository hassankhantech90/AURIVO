import 'dart:typed_data';

import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_exceptions.dart' as ex;
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/supabase/supabase_storage_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// ---------------------------------------------------------------------------
// Row builders
// ---------------------------------------------------------------------------

Map<String, dynamic> profileRow({
  String id = 'profile-1',
  String userId = 'auth-1',
  String fullName = 'Aya Khan',
  String? email = 'aya@aurivo.pk',
  String? phone = '03001234567',
  String? avatarPath,
}) {
  return {
    'id': id,
    'user_id': userId,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'avatar_path': avatarPath,
    'status': 'active',
    'is_phone_verified': false,
    'is_email_verified': false,
  };
}

Map<String, dynamic> addressRow({
  String id = 'addr-1',
  String profileId = 'profile-1',
  String addressType = 'shipping',
  String recipientName = 'Aya Khan',
  String phone = '03001234567',
  String addressLine1 = 'House 1, Street 2',
  String city = 'Lahore',
  String province = 'Punjab',
  bool isDefault = false,
}) {
  return {
    'id': id,
    'profile_id': profileId,
    'address_type': addressType,
    'recipient_name': recipientName,
    'phone': phone,
    'address_line_1': addressLine1,
    'city': city,
    'province': province,
    'country': 'Pakistan',
    'is_default': isDefault,
  };
}

Map<String, dynamic> businessRow({
  String id = 'biz-1',
  String profileId = 'profile-1',
  String businessName = 'Aurivo Traders',
  String contactPerson = 'Aya Khan',
  String contactPhone = '03001234567',
}) {
  return {
    'id': id,
    'profile_id': profileId,
    'business_name': businessName,
    'contact_person': contactPerson,
    'contact_phone': contactPhone,
    'verification_status': 'pending',
    'documents': const <dynamic>[],
  };
}

Map<String, dynamic> sellerRow({
  String id = 'seller-1',
  String profileId = 'profile-1',
  String storeName = 'Aurivo Store',
  String slug = 'aurivo-store',
}) {
  return {
    'id': id,
    'profile_id': profileId,
    'store_name': storeName,
    'slug': slug,
    'verification_status': 'pending',
    'is_wholesale_enabled': false,
    'rating_average': 0,
    'rating_count': 0,
  };
}

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _StubAuthService extends SupabaseAuthService {
  _StubAuthService({supabase.User? user})
    : _user = user,
      super(supabaseService: const SupabaseService());

  final supabase.User? _user;

  @override
  supabase.User? get currentUser => _user;
}

class _StubDatabase extends SupabaseDatabaseService {
  _StubDatabase() : super(supabaseService: const SupabaseService());

  Object? throwError;
  List<Map<String, dynamic>> Function(
    String table,
    Map<String, Object?> filters,
  )?
  onSelect;
  Map<String, dynamic> Function(String table, Map<String, dynamic> values)?
  onInsert;
  Map<String, dynamic> Function(String table, Map<String, dynamic> values)?
  onUpdate;
  Object? rpcResult;

  final List<Map<String, dynamic>> inserted = [];
  final List<Map<String, dynamic>> updated = [];
  final List<Map<String, dynamic>> deleted = [];

  @override
  Future<List<Map<String, dynamic>>> select({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
  }) async {
    if (throwError != null) throw throwError!;
    return onSelect?.call(table, filters) ?? const [];
  }

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (throwError != null) throw throwError!;
    inserted.add({'table': table, ...values});
    return onInsert?.call(table, values) ?? {'id': 'generated-id', ...values};
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    if (throwError != null) throw throwError!;
    updated.add({'table': table, matchColumn: matchValue, ...values});
    return onUpdate?.call(table, values) ?? {'id': matchValue, ...values};
  }

  @override
  Future<void> delete({
    required String table,
    required String matchColumn,
    required Object matchValue,
  }) async {
    if (throwError != null) throw throwError!;
    deleted.add({'table': table, matchColumn: matchValue});
  }

  @override
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    if (throwError != null) throw throwError!;
    return rpcResult;
  }
}

class _StubStorage extends SupabaseStorageService {
  _StubStorage() : super(supabaseService: const SupabaseService());

  Object? throwError;
  final List<Map<String, String>> uploads = [];
  final List<Map<String, String>> deletes = [];

  @override
  Future<String> uploadImage({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
    bool upsert = false,
  }) async {
    if (throwError != null) throw throwError!;
    uploads.add({'bucket': bucket, 'path': path});
    return path;
  }

  @override
  Future<void> deleteImage({
    required String bucket,
    required String path,
  }) async {
    if (throwError != null) throw throwError!;
    deletes.add({'bucket': bucket, 'path': path});
  }

  @override
  String getPublicUrl({required String bucket, required String path}) {
    return 'https://cdn.test/$bucket/$path';
  }
}

supabase.User _user() {
  return supabase.User(
    id: 'auth-1',
    appMetadata: const {},
    userMetadata: const {'full_name': 'Aya Khan', 'phone': '03001234567'},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    email: 'aya@aurivo.pk',
  );
}

void main() {
  late _StubDatabase db;
  late _StubStorage storage;
  late SupabaseProfileRepository repo;

  SupabaseProfileRepository build({supabase.User? user}) {
    return SupabaseProfileRepository(
      database: db,
      storage: storage,
      authService: _StubAuthService(user: user ?? _user()),
    );
  }

  setUp(() {
    db = _StubDatabase();
    storage = _StubStorage();
    repo = build();
  });

  group('profile creation', () {
    test('creates a profile from the auth user when none exists', () async {
      db.onSelect = (table, filters) => const []; // no existing profile
      db.onInsert = (table, values) => profileRow();

      final profile = await repo.ensureProfile();

      expect(db.inserted, hasLength(1));
      final insert = db.inserted.single;
      expect(insert['table'], 'profiles');
      expect(insert['user_id'], 'auth-1');
      expect(insert['full_name'], 'Aya Khan');
      expect(insert['email'], 'aya@aurivo.pk');
      expect(insert['phone'], '03001234567');
      expect(profile.userId, 'auth-1');
    });
  });

  group('duplicate profile prevention', () {
    test('returns the existing profile without inserting', () async {
      db.onSelect = (table, filters) => [profileRow()];

      final profile = await repo.ensureProfile();

      expect(db.inserted, isEmpty);
      expect(profile.id, 'profile-1');
    });
  });

  group('address CRUD', () {
    setUp(() => db.rpcResult = 'profile-1');

    test('adds an address scoped to the current profile', () async {
      db.onInsert = (table, values) => addressRow();

      await repo.addAddress(
        recipientName: 'Aya Khan',
        phone: '03001234567',
        addressLine1: 'House 1, Street 2',
        city: 'Lahore',
        province: 'Punjab',
      );

      expect(db.inserted, hasLength(1));
      expect(db.inserted.single['table'], 'addresses');
      expect(db.inserted.single['profile_id'], 'profile-1');
    });

    test('normalizes a formatted phone before insert', () async {
      db.onInsert = (table, values) => addressRow();

      await repo.addAddress(
        recipientName: 'Aya Khan',
        phone: '0300 1234-567',
        addressLine1: 'House 1, Street 2',
        city: 'Lahore',
        province: 'Punjab',
      );

      // Spaces/dashes stripped so the DB phone CHECK is satisfied.
      expect(db.inserted.single['phone'], '03001234567');
    });

    test('rejects a province outside the allowed set', () async {
      db.onInsert = (table, values) => addressRow();

      await expectLater(
        repo.addAddress(
          recipientName: 'Aya Khan',
          phone: '03001234567',
          addressLine1: 'House 1, Street 2',
          city: 'Lahore',
          province: 'Lahore', // a city, not a valid province
        ),
        throwsA(
          predicate(
            (e) =>
                e is Failure &&
                e.message.toLowerCase().contains('valid province'),
          ),
        ),
      );
      expect(db.inserted, isEmpty); // never reached the database
    });

    test('updates an address by id', () async {
      db.onUpdate = (table, values) =>
          addressRow(recipientName: 'Updated Name');

      final address = await repo.updateAddress(
        addressId: 'addr-1',
        recipientName: 'Updated Name',
      );

      expect(db.updated, hasLength(1));
      expect(db.updated.single['id'], 'addr-1');
      expect(address.recipientName, 'Updated Name');
    });

    test('deletes an address by id', () async {
      await repo.deleteAddress(addressId: 'addr-1');

      expect(db.deleted, hasLength(1));
      expect(db.deleted.single['table'], 'addresses');
      expect(db.deleted.single['id'], 'addr-1');
    });

    test('sets an address as default and clears siblings', () async {
      db.onSelect = (table, filters) {
        if (filters.containsKey('is_default')) {
          return [addressRow(id: 'addr-2', isDefault: true)];
        }
        return [addressRow(id: 'addr-1')];
      };
      db.onUpdate = (table, values) =>
          addressRow(id: 'addr-1', isDefault: true);

      final address = await repo.setDefaultAddress(addressId: 'addr-1');

      expect(address.isDefault, isTrue);
      // addr-2 cleared, addr-1 set.
      expect(
        db.updated.any((u) => u['id'] == 'addr-2' && u['is_default'] == false),
        isTrue,
      );
      expect(
        db.updated.any((u) => u['id'] == 'addr-1' && u['is_default'] == true),
        isTrue,
      );
    });
  });

  group('business profile CRUD', () {
    setUp(() => db.rpcResult = 'profile-1');

    test('creates a business profile', () async {
      db.onInsert = (table, values) => businessRow();

      final biz = await repo.createBusinessProfile(
        businessName: 'Aurivo Traders',
        contactPerson: 'Aya Khan',
        contactPhone: '03001234567',
      );

      expect(db.inserted.single['table'], 'business_profiles');
      expect(db.inserted.single['profile_id'], 'profile-1');
      expect(biz.businessName, 'Aurivo Traders');
    });

    test('reads the current business profile', () async {
      db.onSelect = (table, filters) => [businessRow()];

      final biz = await repo.getBusinessProfile();

      expect(biz, isNotNull);
      expect(biz!.contactPhone, '03001234567');
    });

    test('updates the business profile', () async {
      db.onUpdate = (table, values) => businessRow(businessName: 'New Co');

      final biz = await repo.updateBusinessProfile(businessName: 'New Co');

      expect(db.updated.single['profile_id'], 'profile-1');
      expect(biz.businessName, 'New Co');
    });
  });

  group('seller profile CRUD', () {
    setUp(() => db.rpcResult = 'profile-1');

    test('creates a seller profile', () async {
      db.onInsert = (table, values) => sellerRow();

      final seller = await repo.createSellerProfile(
        storeName: 'Aurivo Store',
        slug: 'aurivo-store',
      );

      expect(db.inserted.single['table'], 'seller_profiles');
      expect(seller.slug, 'aurivo-store');
    });

    test('reads the current seller profile', () async {
      db.onSelect = (table, filters) => [sellerRow()];

      final seller = await repo.getSellerProfile();

      expect(seller, isNotNull);
      expect(seller!.storeName, 'Aurivo Store');
    });

    test('updates the seller profile', () async {
      db.onUpdate = (table, values) => sellerRow(storeName: 'Renamed Store');

      final seller = await repo.updateSellerProfile(storeName: 'Renamed Store');

      expect(db.updated.single['profile_id'], 'profile-1');
      expect(seller.storeName, 'Renamed Store');
    });
  });

  group('avatar upload', () {
    test('generates a unique per-upload object path', () {
      final path = SupabaseProfileRepository.avatarObjectPath('profile-1');
      expect(path, startsWith('profile-1/avatar_'));
      expect(path, endsWith('.jpg'));
    });

    test(
      'uploads under the profile folder and returns a matching public url',
      () async {
        db.onSelect = (table, filters) => [profileRow(avatarPath: null)];

        final url = await repo.uploadAvatar(
          bytes: Uint8List.fromList([1, 2, 3]),
        );

        expect(storage.uploads, hasLength(1));
        expect(storage.uploads.single['bucket'], 'avatars');
        final path = storage.uploads.single['path'] as String;
        expect(path, startsWith('profile-1/avatar_'));
        expect(path, endsWith('.jpg'));
        expect(storage.deletes, isEmpty); // nothing to replace
        expect(url, 'https://cdn.test/avatars/$path');
      },
    );

    test('deletes the previous avatar before replacing', () async {
      db.onSelect = (table, filters) => [
        profileRow(avatarPath: 'profile-1/avatar.jpg'),
      ];

      await repo.uploadAvatar(bytes: Uint8List.fromList([1, 2, 3]));

      expect(storage.deletes, hasLength(1));
      expect(storage.deletes.single['path'], 'profile-1/avatar.jpg');
    });
  });

  group('repository failures', () {
    test('maps a database exception to a Failure', () async {
      db.throwError = const ex.DatabaseException(
        'duplicate key value',
        code: '23505',
      );

      await expectLater(repo.getProfile(), throwsA(isA<Failure>()));
    });

    test('never surfaces a raw Supabase exception', () async {
      db.rpcResult = 'profile-1';
      db.throwError = const ex.DatabaseException('rls denied', code: '42501');

      await expectLater(
        repo.getAddresses(),
        throwsA(
          predicate(
            (error) => error is Failure && error is! ex.AppSupabaseException,
          ),
        ),
      );
    });

    test('requires authentication for profile access', () async {
      final anonRepo = SupabaseProfileRepository(
        database: db,
        storage: storage,
        authService: _StubAuthService(),
      );

      await expectLater(anonRepo.getProfile(), throwsA(isA<Failure>()));
    });
  });
}
