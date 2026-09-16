import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';

/// The press feel, in one place.
///
/// Material's ripple is wrong for this product — it spreads a light circle
/// across a dark tile — so every tappable thing in the app is wrapped in this
/// instead: a small scale and a small fade, matching the `.press` class the
/// mocks use.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Motion.press,
          child: AnimatedOpacity(
            opacity: _down ? 0.88 : 1,
            duration: Motion.press,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A row that tints on press rather than scaling — scaling a full-width row
/// inside a grouped list looks like the list is breathing.
class PressableRow extends StatefulWidget {
  const PressableRow({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<PressableRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Motion.press,
          color: _down ? AppColors.fill2 : const Color(0x00000000),
          child: widget.child,
        ),
      ),
    );
  }
}
