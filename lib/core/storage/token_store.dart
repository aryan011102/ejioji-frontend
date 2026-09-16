import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session lives.
///
/// Access and refresh tokens go to the Keychain on iOS and to
/// EncryptedSharedPreferences on Android. They never touch SharedPreferences,
/// never get written to a log, and never appear in an error message — an
/// exception that quotes a bearer token ends up in a crash reporter.
///
/// `first_unlock_this_device` means the token survives a reboot but does not
/// sync to iCloud or to another device, which is what a device-bound session
/// should do.
class TokenStore {
  const TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _access = 'auth.access';
  static const _refresh = 'auth.refresh';

  Future<String?> readAccess() => _storage.read(key: _access);
  Future<String?> readRefresh() => _storage.read(key: _refresh);

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _access, value: access);
    await _storage.write(key: _refresh, value: refresh);
  }

  Future<void> saveAccess(String access) =>
      _storage.write(key: _access, value: access);

  /// Called on sign-out, on a refused refresh, and on account deletion. It
  /// deletes rather than overwrites so nothing is left to recover.
  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
});

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(secureStorageProvider)),
);
