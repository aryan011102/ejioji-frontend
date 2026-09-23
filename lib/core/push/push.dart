import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Push notifications, and the only file in the app that knows Firebase
/// exists.
///
/// Three things are pushed, all of them from the backend's
/// `notifications/push.py`: a chat message, a chat request, and a request
/// accepted. A push carries the other person's first name, and ids. A chat
/// message's push also carries the start of what was written (the backend's
/// `chat/notify.py`, since 2026-09-23); the other two carry fixed copy.
///
/// Every method here is a no-op unless this build was given a Firebase
/// project ([Env.pushConfigured]) on a platform Firebase Messaging covers.
/// That is deliberate rather than defensive: the project is created outside
/// the repository, and the app has to keep building and running before it
/// exists, including in the browser, where there is no Firebase project and
/// no service worker.
///
/// A push that arrives while the app is open is never shown by the system, on
/// either platform. It comes out of [arrivals] instead, and the app draws its
/// own banner (`app/in_app_banner.dart`), which it can leave out when the
/// person is already reading that conversation. The system banner could not:
/// it knows nothing about which screen is open.
abstract final class Push {
  static bool _ready = false;

  /// Whether Firebase started. False until [init] has run and succeeded.
  static bool get ready => _ready;

  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// Whether this build can do push at all, before anything is tried.
  static bool get supported {
    if (kIsWeb) return false;
    if (!_android && defaultTargetPlatform != TargetPlatform.iOS) return false;
    return Env.pushConfigured(android: _android);
  }

  /// This platform's registration in the Firebase project. The app id and the
  /// key differ between the two; the project and the sender do not.
  static FirebaseOptions get _options => FirebaseOptions(
        apiKey: _android ? Env.fcmAndroidApiKey : Env.fcmIosApiKey,
        appId: _android ? Env.fcmAndroidAppId : Env.fcmIosAppId,
        messagingSenderId: Env.fcmSenderId,
        projectId: Env.fcmProjectId,
        iosBundleId: _android ? null : _bundleId,
      );

  /// What the iOS app is registered as, and what APNs addresses a push to.
  static const _bundleId = 'com.theonebytwo.app';

  /// Starts Firebase. Called once from bootstrap, before the first frame.
  ///
  /// A failure here is swallowed on purpose: a misconfigured or unreachable
  /// Firebase must cost this app its notifications and nothing else.
  static Future<void> init() async {
    if (_ready || !supported) return;
    try {
      await Firebase.initializeApp(options: _options);
      // Off while the app is open: [arrivals] and the in-app banner take over.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      _ready = true;
    } on Object catch (error) {
      debugPrint('Push: Firebase did not start ($error). Notifications off.');
    }
  }

  /// Asks for permission and returns the token for this install, or null if
  /// permission was refused or the token is not available yet.
  ///
  /// Asked for only once signed in, which is also when there is something to
  /// notify about. A first-run prompt before anyone has an account is how an
  /// app gets a permanent no.
  static Future<String?> register() async {
    if (!_ready) return null;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final status = settings.authorizationStatus;
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        return null;
      }
      return await FirebaseMessaging.instance.getToken();
    } on Object catch (error) {
      debugPrint('Push: no token ($error).');
      return null;
    }
  }

  /// A new token for this install. Firebase rotates them on its own, and a
  /// token the server does not have is a notification nobody receives.
  static Stream<String> get tokenRefreshes =>
      _ready ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

  /// Stops this install receiving anything, on sign-out. The server is told
  /// separately (`clearPushToken`); this is the same decision on the phone,
  /// so a token cannot be revived by a stale copy.
  static Future<void> forget() async {
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } on Object catch (error) {
      debugPrint('Push: the token was not deleted ($error).');
    }
  }

  /// The notification that opened the app from cold, if it was one.
  static Future<PushOpen?> launchedBy() async {
    if (!_ready) return null;
    return PushOpen.from(await FirebaseMessaging.instance.getInitialMessage());
  }

  /// Pushes that arrived while the app was open, which the system did not
  /// show. Only ones this build knows how to open come out.
  static Stream<PushShown> get arrivals => _ready
      ? FirebaseMessaging.onMessage
          .map(PushShown.from)
          .where((shown) => shown != null)
          .cast<PushShown>()
      : const Stream.empty();

  /// Notifications tapped while the app was running in the background.
  static Stream<PushOpen> get taps => _ready
      ? FirebaseMessaging.onMessageOpenedApp
          .map(PushOpen.from)
          .where((open) => open != null)
          .cast<PushOpen>()
      : const Stream.empty();
}

/// What a tapped notification was about. Ids only, which is all the server
/// sends and all the app needs to open the right screen.
enum PushKind { message, request, match }

@immutable
class PushOpen {
  const PushOpen({required this.kind, required this.id});

  final PushKind kind;

  /// The match for a message or an accepted request, the request itself for a
  /// new one. Null when a push arrived without one, which is a server bug
  /// rather than something to crash over.
  final String? id;

  /// Reads one of the three `data` payloads. Anything else is ignored: a
  /// newer server may push a kind this build has never heard of.
  static PushOpen? from(RemoteMessage? message) {
    if (message == null) return null;
    final data = message.data;
    final type = data['type'] as String?;
    final matchId = data['match_id'] as String?;
    return switch (type) {
      'message' => PushOpen(kind: PushKind.message, id: matchId),
      'match' => PushOpen(kind: PushKind.match, id: matchId),
      'request' => PushOpen(
          kind: PushKind.request,
          id: data['request_id'] as String?,
        ),
      _ => null,
    };
  }
}

/// A push that arrived while the app was open: what it said, and what tapping
/// it opens.
@immutable
class PushShown {
  const PushShown({required this.open, required this.title, required this.body});

  final PushOpen open;
  final String title;
  final String body;

  /// Null for a push this build cannot open, or one with nothing to say.
  static PushShown? from(RemoteMessage? message) {
    final open = PushOpen.from(message);
    final notification = message?.notification;
    if (open == null || notification == null) return null;
    final title = notification.title?.trim() ?? '';
    final body = notification.body?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return null;
    return PushShown(open: open, title: title, body: body);
  }
}
