import 'package:package_info_plus/package_info_plus.dart';

import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../core/storage/device.dart';

/// What "Report a problem" is about. A problem with a person is a report, not
/// this: reports block, and live in `TrustRepository`.
enum FeedbackTopic {
  bug('bug', 'Something broke'),
  idea('idea', 'An idea'),
  other('other', 'Something else');

  const FeedbackTopic(this.wire, this.label);

  final String wire;
  final String label;
}

/// This build, as "1.0.3 (42)": the version, then the build number. Null when
/// the platform cannot say.
Future<String?> readAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (${info.buildNumber})';
  } on Exception {
    return null;
  }
}

final _versionShape = RegExp(r'^[A-Za-z0-9.\-+() ]{1,32}$');

/// [version] if the server will accept it (support/service.py), else null.
/// A version it refuses would get the whole message refused, so it is left
/// off instead: losing someone's bug report over a build string is the wrong
/// trade.
String? sendableVersion(String? version) {
  final v = version?.trim();
  return v != null && _versionShape.hasMatch(v) ? v : null;
}

/// Feedback about the app itself. It lands on the admin Feedback page, where
/// the team reads it.
class SupportRepository {
  const SupportRepository(this._api);

  final ApiClient _api;

  /// Sends it with the platform and [appVersion], so a bug can be matched to
  /// a build. The server trims the message and refuses a blank one.
  Future<String> sendFeedback({
    required FeedbackTopic topic,
    required String message,
    String? appVersion,
  }) async {
    final platform = DeviceIdentity.platform;
    final version = sendableVersion(appVersion);
    final body = await _api.post(
      Api.feedback,
      body: {
        'topic': topic.wire,
        'message': message,
        if (platform != 'unknown') 'platform': platform,
        if (version != null) 'app_version': version,
      },
    );
    return body.str('id');
  }
}
