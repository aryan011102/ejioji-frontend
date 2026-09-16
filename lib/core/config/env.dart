import 'package:flutter/foundation.dart';

/// Build configuration.
///
/// Everything here arrives through `--dart-define` or `--dart-define-from-file`
/// and nothing is defaulted to a production value. There are no keys, secrets
/// or tokens in this file or anywhere else in the repository: the client holds
/// a base URL and nothing more, and every privileged call is authorised by a
/// token the backend issued to this device.
///
///   flutter run --dart-define-from-file=config/dev.json
///
/// `config/*.json` is gitignored; `config/dev.example.json` is checked in.
enum Flavor { dev, staging, prod }

abstract final class Env {
  static const String _flavorName =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static Flavor get flavor => switch (_flavorName) {
        'prod' => Flavor.prod,
        'staging' => Flavor.staging,
        _ => Flavor.dev,
      };

  static bool get isProd => flavor == Flavor.prod;

  /// No default. A build that forgets to define this should fail loudly at
  /// boot rather than quietly point at localhost in the App Store.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// SHA-256 pins of the leaf or intermediate certificate, base64, comma
  /// separated. Empty in dev; required in prod — see [assertValid].
  static const String certPinsRaw = String.fromEnvironment('CERT_PINS');

  static List<String> get certPins => certPinsRaw
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList(growable: false);

  /// Called once from bootstrap. Fails the build rather than shipping a
  /// misconfigured binary.
  static void assertValid() {
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not defined. Run with '
        '--dart-define-from-file=config/dev.json',
      );
    }
    if (!apiBaseUrl.startsWith('https://') && isProd) {
      throw StateError('API_BASE_URL must be https in a prod build.');
    }
    if (isProd && certPins.isEmpty && !kDebugMode) {
      throw StateError('CERT_PINS must be set in a prod build.');
    }
  }
}
