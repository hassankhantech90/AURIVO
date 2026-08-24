import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provides a stable per-installation UUID used as `push_devices.installation_id`.
/// It is a random UUID persisted in secure storage — never a hardware or
/// advertising identifier.
abstract class InstallationIdService {
  Future<String> getOrCreate();
}

class SecureStorageInstallationIdService implements InstallationIdService {
  const SecureStorageInstallationIdService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'aurivo_push_installation_id';

  @override
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _randomUuidV4();
    await _storage.write(key: _key, value: id);
    return id;
  }

  static String _randomUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).toList();
    return '${h[0]}${h[1]}${h[2]}${h[3]}-${h[4]}${h[5]}-${h[6]}${h[7]}-'
        '${h[8]}${h[9]}-${h[10]}${h[11]}${h[12]}${h[13]}${h[14]}${h[15]}';
  }
}
