import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/push/push.dart';
import 'auth_repository.dart';

/// Keeps the server's idea of this install's push token in step with
/// Firebase's.
///
/// Started when someone signs in, stopped when they sign out. A token that
/// outlived its owner is the one thing that must not happen here: it would
/// send the next person's names to the last person's phone, so signing out
/// deletes it on the device as well as on the server.
class PushRegistration {
  PushRegistration(this._auth);

  final AuthRepository _auth;
  StreamSubscription<String>? _refreshes;

  /// Asks for permission, tells the server the token, and keeps listening:
  /// Firebase rotates tokens on its own, and a token the server does not have
  /// is a notification nobody receives.
  ///
  /// Called on every sign-in and every restored session, which is also how a
  /// token that was refused once gets asked for again after the person turns
  /// notifications on in Settings.
  Future<void> start() async {
    if (!Push.ready) return;
    final token = await Push.register();
    if (token != null) await _send(token);
    _refreshes ??= Push.tokenRefreshes.listen((token) {
      unawaited(_send(token));
    });
  }

  Future<void> stop() async {
    await _refreshes?.cancel();
    _refreshes = null;
    await Push.forget();
  }

  /// Best effort, always. Nothing about signing in or staying signed in may
  /// fail because a notification token could not be registered.
  Future<void> _send(String token) async {
    try {
      await _auth.registerPushToken(token);
    } on ApiException catch (error) {
      debugPrint('Push: the server did not take the token (${error.message}).');
    }
  }
}
