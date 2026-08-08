import 'dart:convert';
import 'dart:math';

import '../../../core/storage/secure_storage_service.dart';

/// Generates and persists a cryptographically random guest-cart token via
/// [SecureStorageService]. The token is the sole scoping key for the
/// server-side guest-cart RPCs, so it must be stable per device and >= 16 chars.
class GuestTokenService {
  GuestTokenService({required SecureStorageService storage})
    : _storage = storage;

  final SecureStorageService _storage;

  static const String storageKey = 'guest_cart_token';

  /// Returns the persisted guest token, creating and storing one if absent.
  Future<String> getOrCreate() async {
    final existing = await _storage.read(storageKey);
    if (existing != null && existing.trim().length >= 16) {
      return existing;
    }
    final token = _generate();
    await _storage.write(key: storageKey, value: token);
    return token;
  }

  Future<String?> current() => _storage.read(storageKey);

  Future<void> clear() => _storage.delete(storageKey);

  String _generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    // URL-safe, ~32 chars (well above the 16-char minimum), no padding.
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
