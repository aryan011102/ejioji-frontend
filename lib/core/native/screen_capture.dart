import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeping other people's profiles and chats out of screenshots and screen
/// recordings, while one is on screen.
///
/// The native halves are MainActivity.kt and ios/Runner/AppDelegate.swift
/// (ScreenCaptureBridge), in-repo rather than a plugin like the MusicKit
/// bridge. They do different things, because the platforms allow different
/// things:
///
/// - **Android** refuses the capture outright (`FLAG_SECURE`): a screenshot is
///   refused with the system's own message, and a recording shows black.
/// - **iOS** has no API that refuses a screenshot. The Swift side draws the app
///   inside a secure text field's layer, which iOS leaves out of screenshots
///   and recordings. That is undocumented and could stop working in any iOS
///   release, so two public APIs back it up: [captured] says a recording or a
///   mirror is running (and [CaptureShield] covers the screen), and
///   [screenshots] says one was taken (and the taker is told it is not
///   allowed).
///
/// Nothing is sent anywhere. Neither half tells the server or the other person.
class ScreenCapture {
  const ScreenCapture._();

  static const _channel = MethodChannel('theonebytwo/screen_capture');

  /// How many screens want protecting right now. The platform only hears about
  /// the change from none to some and back, so moving from one card to the next
  /// never drops the protection in between.
  static int _holds = 0;

  static bool _listening = false;

  /// True while the screen is being recorded or mirrored. iOS only.
  static final captured = ValueNotifier<bool>(false);

  static final _screenshots = StreamController<void>.broadcast();

  /// A screenshot was taken. iOS only, and after the fact: iOS says so once
  /// the picture exists.
  static Stream<void> get screenshots => _screenshots.stream;

  @visibleForTesting
  static int get holds => _holds;

  static void protect() {
    _holds++;
    if (_holds == 1) unawaited(_set(true));
  }

  static void release() {
    if (_holds == 0) return;
    _holds--;
    if (_holds == 0) unawaited(_set(false));
  }

  static Future<void> _set(bool on) async {
    if (kIsWeb) return;
    _listen();
    try {
      // The answer is whether a recording is already running, so a screen
      // opened mid-recording is covered from its first frame.
      final recording = await _channel.invokeMethod<bool>('setProtected', on);
      if (on && _holds > 0) captured.value = recording ?? false;
    } on MissingPluginException {
      // Web, desktop and tests have no native half. Nothing to protect with.
    } on PlatformException {
      // Protection is a deterrent, never a reason to break the screen.
    }
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'screenshot':
          _screenshots.add(null);
        case 'captured':
          captured.value = call.arguments == true;
      }
    });
  }

  @visibleForTesting
  static void reset() {
    _holds = 0;
    _listening = false;
    captured.value = false;
    _channel.setMethodCallHandler(null);
  }
}
