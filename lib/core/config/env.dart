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

  /// Firebase, for push notifications only.
  ///
  /// None of these is a secret: every Android app ships them in plain sight
  /// inside `google-services.json`, and they identify the project rather than
  /// authorise anything. They are defines rather than a checked-in file so
  /// that a build without a Firebase project still builds and runs, with push
  /// simply off. What actually sends a push is a service-account key, and
  /// that lives on the server and never comes near this app.
  ///
  /// The project and the sender are one project-wide pair. The app id and the
  /// api key are per platform, because Firebase registers a phone app once per
  /// platform: the Android values come from `google-services.json` and the
  /// iOS ones from `GoogleService-Info.plist`, and crossing them over is a
  /// registration Firebase will refuse.
  static const String fcmProjectId = String.fromEnvironment('FCM_PROJECT_ID');
  static const String fcmSenderId = String.fromEnvironment('FCM_SENDER_ID');
  static const String fcmAndroidAppId =
      String.fromEnvironment('FCM_ANDROID_APP_ID');
  static const String fcmAndroidApiKey =
      String.fromEnvironment('FCM_ANDROID_API_KEY');
  static const String fcmIosAppId = String.fromEnvironment('FCM_IOS_APP_ID');
  static const String fcmIosApiKey = String.fromEnvironment('FCM_IOS_API_KEY');

  /// Whether this build was given a Firebase project to talk to, with the
  /// pair for the platform it is running on. Everything in `core/push` is a
  /// no-op while this is false.
  static bool pushConfigured({required bool android}) {
    final appId = android ? fcmAndroidAppId : fcmIosAppId;
    final apiKey = android ? fcmAndroidApiKey : fcmIosApiKey;
    return fcmProjectId.isNotEmpty &&
        fcmSenderId.isNotEmpty &&
        appId.isNotEmpty &&
        apiKey.isNotEmpty;
  }

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
