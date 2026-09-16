import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/tiles.dart';

/// The floor. A wall cannot be emptied below what the setup flow approved, so
/// the last six tiles refuse to be removed.
const kMinTiles = 6;

/// Arrange mode.
///
/// Drag anywhere on a tile to move it; the ✕ takes it off. Both are edits, so
/// neither writes — the profile goes dirty and the foot becomes Save.
///
/// Dragging is long-press rather than immediate, because the wall scrolls: an
/// immediate drag would fight every scroll gesture on the screen.
class ArrangeWall extends StatefulWidget {
  const ArrangeWall({
    required this.order,
    required this.onReorder,
    required this.onRemove,
    required this.onFloorHit,
    super.key,
  });

  final List<String> order;
  final void Function(String moved, String target) onReorder;
  final void Function(String id) onRemove;

  /// Called instead of removing when the wall is already at the floor.
  final VoidCallback onFloorHit;

  @override
  State<ArrangeWall> createState() => _ArrangeWallState();
}

class _ArrangeWallState extends State<ArrangeWall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  String? _dragging;

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  DemoInsight _byId(String id) =>
      Demo.wall.firstWhere((t) => t.id == id);

  @override
  Widget build(BuildContext context) {
    final canRemove = widget.order.length > kMinTiles;

    return BentoGrid(
      children: [
        for (final id in widget.order)
          BentoItem(
            size: _byId(id).size,
            child: _ArrangeableTile(
              insight: _byId(id),
              wobble: _wobble,
              dragging: _dragging == id,
              canRemove: canRemove,
              onDragStart: () => setState(() => _dragging = id),
              onDragEnd: () => setState(() => _dragging = null),
              onAccept: (moved) => widget.onReorder(moved, id),
              onRemove: () =>
                  canRemove ? widget.onRemove(id) : widget.onFloorHit(),
            ),
          ),
      ],
    );
  }
}

class _ArrangeableTile extends StatelessWidget {
  const _ArrangeableTile({
    required this.insight,
    required this.wobble,
    required this.dragging,
    required this.canRemove,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onAccept,
    required this.onRemove,
  });

  final DemoInsight insight;
  final Animation<double> wobble;
  final bool dragging;
  final bool canRemove;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<String> onAccept;
  final VoidCallback onRemove;

  Widget _tile({bool ghost = false}) => Opacity(
        opacity: ghost ? 0.9 : 1,
        child: InsightTile(
          size: insight.size,
          number: insight.number,
          caption: insight.caption,
          prompt: insight.prompt,
          answer: insight.answer,
          tone: insight.tone,
          hasMedia: insight.media,
          isTrack: insight.track,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != insight.id,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidate, rejected) {
        final hovered = candidate.isNotEmpty;

        return AnimatedBuilder(
          animation: wobble,
          builder: (context, child) {
            // A small alternating tilt, phase-shifted per tile so the wall does
            // not pulse in unison and read as a glitch.
            final phase = insight.id.hashCode % 6;
            final angle =
                math.sin((wobble.value * 2 * math.pi) + phase) * 0.012;
            return Transform.rotate(angle: dragging ? 0 : angle, child: child);
          },
          child: LongPressDraggable<String>(
            data: insight.id,
            onDragStarted: onDragStart,
            onDragEnd: (_) => onDragEnd(),
            onDraggableCanceled: (_, __) => onDragEnd(),
            feedback: SizedBox(
              width: insight.size.crossAxisCells * 170,
              height: insight.size.mainAxisCells * 170,
              child: Material(
                color: const Color(0x00000000),
                child: _tile(ghost: true),
              ),
            ),
            childWhenDragging: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.fill2,
                borderRadius: BorderRadius.circular(Radii.tile),
                border: Border.all(color: AppColors.hairline),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: _tile()),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: hovered
                          ? const Color(0x4DEF798A)
                          : const Color(0x47000000),
                      borderRadius: BorderRadius.circular(Radii.tile),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.open_with,
                        size: 22,
                        color: AppColors.label,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 9,
                  left: 9,
                  child: Pressable(
                    onTap: onRemove,
                    semanticLabel: 'Remove from profile',
                    child: Opacity(
                      // At the floor the ✕ dims but still taps — and says why,
                      // rather than doing nothing.
                      opacity: canRemove ? 1 : 0.6,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xF0FFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 15,
                          color: Color(0xFF1A1116),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
