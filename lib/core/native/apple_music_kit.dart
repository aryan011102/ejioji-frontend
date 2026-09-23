import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Apple Music's own permission prompt, and the Music User Token it gives back.
///
/// The Swift half is in ios/Runner/AppDelegate.swift (AppleMusicBridge). It is a
/// dozen lines on Apple's MusicKit rather than a plugin, so no third-party code
/// ever holds the token. Nothing here keeps it either: it goes straight to our
/// server, which reads the library once with it and lets it go.
///
/// iOS only. Apple ships MusicKit for Android as a separate SDK, and there is
/// no Android phone to test on yet, so Android does not offer Apple Music.
class AppleMusicKit {
  const AppleMusicKit._();

  static const _channel = MethodChannel('theonebytwo/apple_music');

  static bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Shows Apple's prompt if the person has not answered it yet, then asks
  /// MusicKit for a user token signed against our [developerToken].
  ///
  /// Throws [AppleMusicDenied] when they say no. If they said no before, iOS
  /// does not ask again and only Settings can change it, which
  /// [AppleMusicDenied.inSettings] says.
  static Future<String> userToken(String developerToken) async {
    try {
      final token = await _channel.invokeMethod<String>(
        'userToken',
        {'developerToken': developerToken},
      );
      if (token == null || token.isEmpty) {
        throw const AppleMusicUnavailable('no token came back');
      }
      return token;
    } on PlatformException catch (e) {
      final detail = e.details is String ? e.details as String : null;
      switch (e.code) {
        case 'denied':
          throw const AppleMusicDenied();
        case 'denied_in_settings':
          throw const AppleMusicDenied(inSettings: true);
      }
      // MusicKit saying no after the prompt said yes means access is off for
      // this app somewhere only Settings reaches.
      if (detail == 'permission_denied') {
        throw const AppleMusicDenied(inSettings: true);
      }
      throw AppleMusicUnavailable(e.code, detail: detail);
    } on MissingPluginException {
      throw const AppleMusicUnavailable('not on this platform');
    }
  }
}

/// The person said no on Apple's prompt, now or earlier.
class AppleMusicDenied implements Exception {
  const AppleMusicDenied({this.inSettings = false});

  /// They said no before, or a parent or employer restricts it, so the prompt
  /// was not shown this time. Only Settings can change it now.
  final bool inSettings;
}

/// MusicKit could not produce a token: no Apple ID signed in, a network
/// failure, or a platform without MusicKit. [reason] is for logs only.
class AppleMusicUnavailable implements Exception {
  const AppleMusicUnavailable(this.reason, {this.detail});

  final String reason;

  /// Apple's own reason, as one of the Swift side's fixed words:
  /// `developer_token`, `privacy_acknowledgement`, `not_signed_in`,
  /// `user_token`, `unknown` or `other`. Null when Swift did not say.
  final String? detail;

  @override
  String toString() => 'AppleMusicUnavailable($reason, $detail)';
}
