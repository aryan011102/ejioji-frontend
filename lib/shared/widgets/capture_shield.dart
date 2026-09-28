import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/native/screen_capture.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'sheets.dart';

/// Wrap a screen that shows somebody else: their profile, or a conversation
/// with them (and the photos in it).
///
/// While any shield is on screen the phone is asked to keep the app out of
/// screenshots and recordings ([ScreenCapture] says how far each platform
/// goes). If a recording or a mirror is running anyway, the screen is covered.
/// If a screenshot is taken anyway, whoever took it is told it is not allowed.
/// Your own profile and every other screen are left alone.
class CaptureShield extends StatefulWidget {
  const CaptureShield({required this.child, super.key});

  final Widget child;

  static const screenshotNote =
      "Screenshots of people's profiles and chats aren't allowed.";

  static const recordingNote = 'Hidden while your screen is recorded or shared.';

  @override
  State<CaptureShield> createState() => _CaptureShieldState();
}

class _CaptureShieldState extends State<CaptureShield> {
  /// Every shield on screen, oldest first. A conversation opened from a
  /// profile leaves the profile's shield mounted underneath, and only one of
  /// them should say anything about a screenshot.
  static final _live = <_CaptureShieldState>[];

  StreamSubscription<void>? _shots;

  @override
  void initState() {
    super.initState();
    _live.add(this);
    ScreenCapture.protect();
    _shots = ScreenCapture.screenshots.listen((_) => _onScreenshot());
  }

  @override
  void dispose() {
    unawaited(_shots?.cancel());
    _live.remove(this);
    ScreenCapture.release();
    super.dispose();
  }

  /// The shield the person is looking at: the newest one on the top route.
  static _CaptureShieldState? get _front {
    for (final s in _live.reversed) {
      if (s.mounted && (ModalRoute.isCurrentOf(s.context) ?? true)) return s;
    }
    return null;
  }

  void _onScreenshot() {
    if (!identical(_front, this)) return;
    showAppToast(context, CaptureShield.screenshotNote);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ScreenCapture.captured,
      child: widget.child,
      builder: (context, recording, child) => Stack(
        children: [
          child!,
          if (recording)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.group,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      CaptureShield.recordingNote,
                      textAlign: TextAlign.center,
                      style: AppText.callout.copyWith(color: AppColors.label2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
