import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/models/media.dart';
import '../../../shared/models/tile.dart' as api;
import '../../../shared/models/tile_look.dart';
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
    required this.tiles,
    required this.mediaOf,
    required this.onReorder,
    required this.onRemove,
    required this.onFloorHit,
    super.key,
  });

  /// In the order they are shown. A tile is identified by its key, which is
  /// stable across a refresh, so rearranging and then re-pulling a source
  /// does not scatter the wall.
  final List<api.ProfileTile> tiles;

  /// What sits behind each tile, so arranging does not strip the photos off.
  final MediaAsset? Function(api.ProfileTile) mediaOf;

  final void Function(String movedKey, String targetKey) onReorder;
  final void Function(String key) onRemove;

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

  @override
  Widget build(BuildContext context) {
    final canRemove = widget.tiles.length > kMinTiles;

    return BentoGrid(
      children: [
        for (final tile in widget.tiles)
          BentoItem(
            size: tile.tileSize,
            child: _ArrangeableTile(
              tile: tile,
              media: widget.mediaOf(tile),
              wobble: _wobble,
              dragging: _dragging == tile.key,
              canRemove: canRemove,
              onDragStart: () => setState(() => _dragging = tile.key),
              onDragEnd: () => setState(() => _dragging = null),
              onAccept: (moved) => widget.onReorder(moved, tile.key),
              onRemove: () =>
                  canRemove ? widget.onRemove(tile.key) : widget.onFloorHit(),
            ),
          ),
      ],
    );
  }
}

class _ArrangeableTile extends StatelessWidget {
  const _ArrangeableTile({
    required this.tile,
    required this.media,
    required this.wobble,
    required this.dragging,
    required this.canRemove,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onAccept,
    required this.onRemove,
  });

  final api.ProfileTile tile;
  final MediaAsset? media;
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
          size: tile.tileSize,
          number: tile.isAnswer ? null : tile.headline,
          caption: tile.isAnswer ? null : tile.body,
          prompt: tile.question,
          answer: tile.isAnswer ? tile.headline : null,
          tone: tile.tone,
          isTrack: tile.looksLikeTrack,
          // The still only: a wall of wobbling tiles is no place to play clips.
          mediaUrl: media?.stillUrl,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != tile.key,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidate, rejected) {
        final hovered = candidate.isNotEmpty;

        return AnimatedBuilder(
          animation: wobble,
          builder: (context, child) {
            // A small alternating tilt, phase-shifted per tile so the wall does
            // not pulse in unison and read as a glitch.
            final phase = tile.key.hashCode % 6;
            final angle =
                math.sin((wobble.value * 2 * math.pi) + phase) * 0.012;
            return Transform.rotate(angle: dragging ? 0 : angle, child: child);
          },
          child: LongPressDraggable<String>(
            data: tile.key,
            onDragStarted: onDragStart,
            onDragEnd: (_) => onDragEnd(),
            onDraggableCanceled: (_, __) => onDragEnd(),
            feedback: SizedBox(
              width: tile.tileSize.crossAxisCells * 170,
              height: tile.tileSize.mainAxisCells * 170,
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
