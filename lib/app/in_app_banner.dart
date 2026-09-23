import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/push/push.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

/// Which conversations are on screen right now, newest on top.
///
/// A conversation page adds itself when it opens and takes itself off when it
/// closes. A push about a conversation somebody is already reading is not
/// shown: the message is on the screen in front of them.
///
/// A list rather than one id, because a conversation can be opened on top of
/// another (from a notification), and closing the top one must leave the one
/// underneath counted. Only the top one counts as open.
abstract final class OpenConversations {
  static final _open = <String>[];

  static void opened(String matchId) => _open.add(matchId);

  static void closed(String matchId) {
    final at = _open.lastIndexOf(matchId);
    if (at >= 0) _open.removeAt(at);
  }

  static String? get top => _open.isEmpty ? null : _open.last;
}

/// The app's own banner for a push that arrived while it was open.
///
/// The system's banner is switched off while the app is open (`Push.init`),
/// because it would show a message over the very conversation it came from.
/// This one asks [shouldShow] first. It sits at the top of the screen for
/// [visibleFor], a newer push replaces it, a swipe up dismisses it, and a tap
/// opens what it was about, like tapping the system notification would.
class InAppBanner extends StatefulWidget {
  const InAppBanner({
    required this.arrivals,
    required this.shouldShow,
    required this.onTap,
    required this.child,
    this.visibleFor = const Duration(seconds: 4),
    super.key,
  });

  final Stream<PushShown> arrivals;
  final bool Function(PushShown shown) shouldShow;
  final void Function(PushOpen open) onTap;
  final Widget child;
  final Duration visibleFor;

  @override
  State<InAppBanner> createState() => _InAppBannerState();
}

class _InAppBannerState extends State<InAppBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  StreamSubscription<PushShown>? _arrivals;
  Timer? _hide;
  PushShown? _shown;

  @override
  void initState() {
    super.initState();
    _arrivals = widget.arrivals.listen(_arrived);
  }

  @override
  void dispose() {
    unawaited(_arrivals?.cancel());
    _hide?.cancel();
    _slide.dispose();
    super.dispose();
  }

  void _arrived(PushShown shown) {
    if (!mounted || !widget.shouldShow(shown)) return;
    setState(() => _shown = shown);
    unawaited(_slide.forward());
    _hide?.cancel();
    _hide = Timer(widget.visibleFor, _dismiss);
  }

  Future<void> _dismiss() async {
    _hide?.cancel();
    await _slide.reverse();
    if (mounted) setState(() => _shown = null);
  }

  void _tapped() {
    final shown = _shown;
    unawaited(_dismiss());
    if (shown != null) widget.onTap(shown.open);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Stack(
      children: [
        widget.child,
        if (shown != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -1.4),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic),
                  ),
                  child: GestureDetector(
                    onTap: _tapped,
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < 0) {
                        unawaited(_dismiss());
                      }
                    },
                    child: _Banner(shown: shown),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.shown});

  final PushShown shown;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      button: true,
      label: [shown.title, shown.body].where((s) => s.isNotEmpty).join('. '),
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassEdge),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_rounded,
                      size: 22,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (shown.title.isNotEmpty)
                            Text(
                              shown.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodyStrong
                                  .copyWith(color: AppColors.label),
                            ),
                          if (shown.body.isNotEmpty)
                            Text(
                              shown.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.callout,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
