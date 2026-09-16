import 'dart:math';

/// Random identifiers, made here rather than pulled in as a dependency.
///
/// Two callers need one. A message carries a `client_id` the device invents
/// before sending, so the server can make a retry after a lost response into
/// one message rather than two; and an install carries a device key, so a
/// push token can be tied to the phone it belongs to.
abstract final class Ids {
  static final Random _random = Random.secure();

  /// A version 4 UUID, in the lowercase hyphenated form the API expects.
  ///
  /// `Random.secure()` rather than `Random()`: a guessable `client_id` would
  /// let someone collide with another person's in-flight message.
  static String uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Version 4, variant 10xx, per RFC 4122.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
