import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// A tile that slides left to show "Chat about this" behind it, as a chat
/// slides in WhatsApp to show its actions.
///
/// Two ways to fire it: slide it open and tap the action, or slide it most of
/// the way across in one go. The action is drawn inside the tile's own frame,
/// never beside it: on a bento grid the space beside a tile is the next tile.
///
/// A short tile has no room for the words, so it shows the bubble alone.
class SwipeToChat extends StatefulWidget {
  const SwipeToChat({
    required this.child,
    required this.onChat,
    this.label = 'Chat about this',
    super.key,
  });

  final Widget child;
  final VoidCallback onChat;
  final String label;

  @override
  State<SwipeToChat> createState() => _SwipeToChatState();
}

class _SwipeToChatState extends State<SwipeToChat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<double>? _towards;

  /// How far the tile has moved left, in pixels. Never negative.
  double _offset = 0;
  double _width = 0;
  bool _pastFire = false;

  /// How far it rests when opened: room for the action and no more.
  double get _reveal => (_width * 0.5).clamp(64.0, 140.0);

  /// Released past this, it fires without the tap.
  double get _fireAt => _width * 0.6;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() {
      final towards = _towards;
      if (towards != null) setState(() => _offset = towards.value);
    });
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _towards = Tween(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _snap, curve: Curves.easeOutCubic),
    );
    _snap.forward(from: 0);
  }

  void _onUpdate(DragUpdateDetails d) {
    _snap.stop();
    final next = (_offset - d.delta.dx).clamp(0.0, _width * 0.8);
    final past = next >= _fireAt;
    // One tap of the engine as it crosses into "let go and it sends".
    if (past != _pastFire) HapticFeedback.mediumImpact();
    setState(() {
      _offset = next;
      _pastFire = past;
    });
  }

  void _onEnd(DragEndDetails d) {
    final flung = (d.primaryVelocity ?? 0) < -900;
    if (_offset >= _fireAt) {
      _fire();
    } else if (_offset > _reveal / 2 || flung) {
      _animateTo(_reveal);
    } else {
      _animateTo(0);
    }
    _pastFire = false;
  }

  void _fire() {
    _animateTo(0);
    widget.onChat();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final open = _offset > 0;
        final roomy = _reveal >= 110;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              if (open)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.tile),
                    child: Semantics(
                      button: true,
                      label: widget.label,
                      child: GestureDetector(
                        onTap: _fire,
                        child: ColoredBox(
                          color: _pastFire ? AppColors.accent : AppColors.fill,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: _offset.clamp(0.0, _reveal),
                              child: Opacity(
                                opacity: (_offset / _reveal).clamp(0.0, 1.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: AppColors.onAccent,
                                      size: 24,
                                    ),
                                    if (roomy) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.label,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        style: AppText.footnote.copyWith(
                                          color: AppColors.onAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(-_offset, 0),
                child: open
                    // While open, a tap on the tile closes it rather than
                    // doing whatever the tile does.
                    ? GestureDetector(
                        onTap: () => _animateTo(0),
                        child: AbsorbPointer(child: widget.child),
                      )
                    : widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}
