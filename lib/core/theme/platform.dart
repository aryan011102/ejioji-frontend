import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// The two places this app is not the same app.
///
/// There are exactly two platform differences and they are both deliberate:
/// the typeface, and where the tab bar sits. Everything else is identical, and
/// any new `if (isAndroid)` needs a better reason than "that is how Android
/// does it" — a product should feel like itself first.
abstract final class AppPlatform {
  /// Overridable so widget tests can assert both layouts without a device.
  @visibleForTesting
  static bool? debugOverrideAndroid;

  static bool get isAndroid {
    if (debugOverrideAndroid != null) return debugOverrideAndroid!;
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  static bool get isIOS => !isAndroid;

  /// iOS floats the bar over the wall with the profile scrolling underneath,
  /// which is the whole point of the glass. Android docks it to the bottom
  /// edge, where its system bars already live, and drops the glass — a
  /// translucent bar sitting on a gesture bar reads as an accident.
  static bool get floatingTabBar => isIOS;
}
