import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../util/ids.dart';
import 'token_store.dart';

/// This install, named.
///
/// The server ties a session and a push token to a device key, so that signing
/// out everywhere can clear them and a phone that changes hands stops showing
/// the previous account's names. It is an opaque random id, not a hardware
/// identifier: a real device id would follow the person across uninstalls and
/// across apps, which is tracking rather than a session.
class DeviceIdentity {
  DeviceIdentity(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'device.key';

  String? _cached;

  /// Stable for the life of the install. It is generated on first use and
  /// kept beside the tokens, so clearing the app clears it too.
  Future<String> key() async {
    final cached = _cached;
    if (cached != null) return cached;

    final stored = await _storage.read(key: _key);
    if (stored != null && stored.isNotEmpty) {
      _cached = stored;
      return stored;
    }

    final made = Ids.uuid();
    await _storage.write(key: _key, value: made);
    _cached = made;
    return made;
  }

  /// What the API calls this platform.
  static String get platform {
    if (kIsWeb) return 'unknown';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }
}

final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => DeviceIdentity(ref.watch(secureStorageProvider)),
);
