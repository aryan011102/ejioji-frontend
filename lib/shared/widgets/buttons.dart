import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'pressable.dart';

/// The filled one. There is at most one on a screen, and it is the thing the
/// screen is for.
///
/// Disabled is a real state, not a hidden button: it keeps its place in the
/// layout and goes flat, so the screen does not reflow the moment a form
/// becomes valid.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? AppColors.fill : AppColors.fill2,
          borderRadius: BorderRadius.circular(Radii.control),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: AppColors.glow,
                    blurRadius: 22,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: busy
            ? const _Spinner(color: AppColors.onAccent)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(
                    label,
                    style: AppText.button.copyWith(
                      color: enabled ? AppColors.onAccent : AppColors.label4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The outlined one. Same height as primary so a pair of them sits level.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.row,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: AppColors.hairline),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 8)],
            Text(label, style: AppText.button.copyWith(color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

/// Solid red. Used only where the action itself is the destruction — deleting
/// an account, not leaving a screen.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({required this.label, this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.destructive,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.button.copyWith(color: AppColors.onAccent),
        ),
      ),
    );
  }
}

/// A bare label. The way out of a screen, or the smaller of two choices.
class TextActionButton extends StatelessWidget {
  const TextActionButton({
    required this.label,
    this.onPressed,
    this.destructive = false,
    this.dim = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          label,
          style: AppText.navAction.copyWith(
            color: destructive
                ? AppColors.destructive
                : dim
                    ? AppColors.label2
                    : AppColors.accent,
          ),
        ),
      ),
    );
  }
}

/// A small filled or outlined chip used inside rows and cards — Verify,
/// Refresh, Unblock, Copy.
class MiniButton extends StatelessWidget {
  const MiniButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.tone = MiniTone.filled,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final MiniTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      MiniTone.filled => (AppColors.fill, AppColors.onAccent, null),
      MiniTone.quiet => (AppColors.fill2, AppColors.accent, null),
      MiniTone.destructive => (
          const Color(0x00000000),
          AppColors.destructive,
          AppColors.hairline,
        ),
    };

    return Pressable(
      onTap: onPressed,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: border == null ? null : Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            Text(
              label,
              style: AppText.footnote.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum MiniTone { filled, quiet, destructive }

class _Spinner extends StatefulWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CustomPaint(painter: _ArcPainter(widget.color)),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Offset.zero & size,
      -1.6,
      4.2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}
