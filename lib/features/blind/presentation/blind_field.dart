import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/blind.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/tile_look.dart';
import '../../../shared/widgets/tiles.dart';
import 'blind_layout.dart';

/// The size of things on the plane, from the screen's width.
///
/// A cell is the profile wall's cell, two to a screen inside the gutters, so a
/// tile here is the size it is on the profile it opens.
class BlindGeometry {
  BlindGeometry(double width)
      : cell = math.max(120, (width - 2 * Insets.gutter - gap) / 2);

  static const gap = 12.0;
  final double cell;

  double get step => cell + gap;
  double get blockWidth => BlindLayout.cols * step;
  double get blockHeight => BlindLayout.rows * step;

  Size box(TileSize size) => Size(
        size.crossAxisCells * cell + (size.crossAxisCells - 1) * gap,
        size.mainAxisCells * cell + (size.mainAxisCells - 1) * gap,
      );
}

/// A plane you drag in any direction, with no top, no end and no first tile.
///
/// A tap on a tile opens whose it is. A quick flick to the right on one asks
/// to chat about it: quick, because a slow drag to the right is just moving,
/// and the plane has to stay free to move every way.
class BlindField extends StatefulWidget {
  const BlindField({
    required this.layout,
    required this.topInset,
    required this.onOpen,
    required this.onChat,
    required this.onRunningLow,
    this.asked = const {},
    this.showCategory = true,
    super.key,
  });

  final BlindLayout layout;

  /// What floats over the top edge (the tabs), so the first row starts below
  /// it rather than under it.
  final double topInset;

  final ValueChanged<BlindTile> onOpen;
  final Future<void> Function(BlindTile) onChat;

  /// The plane has laid down most of what it has: time for the next page.
  final VoidCallback onRunningLow;

  /// People already asked from here, by user id.
  final Set<String> asked;

  /// The category's glyph on each tile. On All the mix is the point, so the
  /// glyph earns its place; under one tab it would say the same thing on
  /// every tile.
  final bool showCategory;

  @override
  State<BlindField> createState() => _BlindFieldState();
}

class _BlindFieldState extends State<BlindField> with TickerProviderStateMixin {
  /// Where the plane's origin is on screen. Starts with the first block's
  /// left edge on the gutter, so the opening view is clean on the left, where
  /// a tile's number starts, and bleeds off to the right and down.
  Offset _offset = Offset.zero;
  bool _placed = false;

  /// Built in initState: a ticker first touched in dispose is created during
  /// unmount, which throws, and opening Blind and leaving without dragging is
  /// exactly that path.
  late final Ticker _glide;
  Offset _velocity = Offset.zero;
  Duration _lastTick = Duration.zero;

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Offset>? _snapTo;

  // The drag in progress, for telling a flick from a move.
  Offset _dragFrom = Offset.zero;
  Offset _offsetAtDrag = Offset.zero;
  Duration _dragStarted = Duration.zero;
  final Stopwatch _clock = Stopwatch()..start();

  /// The tile being asked about, lit while its sheet is up.
  String? _chatting;

  late BlindGeometry _geo;

  /// A flick is short, fast and mostly sideways. Anything else moves the
  /// plane.
  static const _flickWithin = Duration(milliseconds: 280);
  static const _flickSpeed = 900.0;

  @override
  void initState() {
    super.initState();
    _glide = createTicker(_onGlide);
    _snap.addListener(() {
      final to = _snapTo;
      if (to != null) setState(() => _offset = to.value);
    });
  }

  @override
  void dispose() {
    _glide.dispose();
    _snap.dispose();
    super.dispose();
  }

  /// Momentum, with framerate-independent decay so it feels the same at 60
  /// and 120Hz. A field you have to keep re-grabbing is a chore, not a wander.
  void _onGlide(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    final next = _offset + _velocity * dt;
    _velocity *= math.pow(0.08, dt).toDouble();
    if (_velocity.distance < 24) _stopGlide();
    setState(() => _offset = next);
  }

  void _stopGlide() {
    if (_glide.isActive) _glide.stop();
    _lastTick = Duration.zero;
  }

  void _onPanStart(DragStartDetails d) {
    _stopGlide();
    _snap.stop();
    _velocity = Offset.zero;
    _dragFrom = d.localPosition;
    _offsetAtDrag = _offset;
    _dragStarted = _clock.elapsed;
  }

  void _onPanUpdate(DragUpdateDetails d) => setState(() => _offset += d.delta);

  void _onPanEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    final quick = _clock.elapsed - _dragStarted < _flickWithin;
    final moved = _offset - _offsetAtDrag;
    if (quick &&
        v.dx > _flickSpeed &&
        v.dx > v.dy.abs() * 2 &&
        moved.dx > 16) {
      final tile = _tileAt(_dragFrom);
      if (tile != null) {
        unawaited(_flickToChat(tile));
        return;
      }
    }
    if (v.distance < 120) return;
    _velocity = v;
    _lastTick = Duration.zero;
    _glide.start();
  }

  /// Puts the plane back where the flick found it, lights the tile, and asks.
  Future<void> _flickToChat(BlindTile tile) async {
    HapticFeedback.mediumImpact();
    _snapTo = Tween(begin: _offset, end: _offsetAtDrag).animate(
      CurvedAnimation(parent: _snap, curve: Curves.easeOutCubic),
    );
    setState(() => _chatting = tile.id);
    unawaited(_snap.forward(from: 0));
    try {
      await widget.onChat(tile);
    } finally {
      if (mounted) setState(() => _chatting = null);
    }
  }

  /// The tile under a point on screen, if any (a gap is no tile).
  BlindTile? _tileAt(Offset local) {
    final p = local - _offsetAtDrag;
    final bx = (p.dx / _geo.blockWidth).floor();
    final by = (p.dy / _geo.blockHeight).floor();
    final q = p - Offset(bx * _geo.blockWidth, by * _geo.blockHeight);
    final tiles = widget.layout.block(bx, by);
    for (var k = 0; k < tiles.length; k++) {
      final (col, row, size) = BlindLayout.slots[k];
      final rect = Offset(col * _geo.step, row * _geo.step) & _geo.box(size);
      if (rect.contains(q)) return tiles[k];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _geo = BlindGeometry(constraints.maxWidth);
        if (!_placed) {
          _placed = true;
          _offset = Offset(Insets.gutter, widget.topInset);
        }
        final view = Offset.zero & constraints.biggest;
        final children = <Widget>[];

        final firstX = ((-_offset.dx) / _geo.blockWidth).floor();
        final lastX = ((view.width - _offset.dx) / _geo.blockWidth).floor();
        final firstY = ((-_offset.dy) / _geo.blockHeight).floor();
        final lastY = ((view.height - _offset.dy) / _geo.blockHeight).floor();

        for (var bx = firstX; bx <= lastX; bx++) {
          for (var by = firstY; by <= lastY; by++) {
            final tiles = widget.layout.block(bx, by);
            final origin =
                _offset + Offset(bx * _geo.blockWidth, by * _geo.blockHeight);
            for (var k = 0; k < tiles.length; k++) {
              final (col, row, size) = BlindLayout.slots[k];
              final rect =
                  origin + Offset(col * _geo.step, row * _geo.step) &
                      _geo.box(size);
              // Only what is on screen is built, which matters most for the
              // videos: one off screen would still be playing.
              if (!rect.overlaps(view)) continue;
              final t = tiles[k];
              children.add(
                Positioned.fromRect(
                  rect: rect,
                  child: _Tile(
                    // Keyed by place and tile, so a video keeps playing while
                    // the plane moves under it.
                    key: ValueKey('$bx:$by:$k:${t.id}'),
                    tile: t,
                    size: size,
                    showCategory: widget.showCategory,
                    asked: widget.asked.contains(t.person.userId),
                    chatting: _chatting == t.id,
                    onTap: () => widget.onOpen(t),
                  ),
                ),
              );
            }
          }
        }

        if (widget.layout.runningLow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onRunningLow();
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: ClipRect(child: Stack(children: children)),
        );
      },
    );
  }
}

/// One tile on the plane: the profile's own tile, so the line met here is the
/// line on their profile, not a teaser written for this screen.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.tile,
    required this.size,
    required this.showCategory,
    required this.asked,
    required this.chatting,
    required this.onTap,
    super.key,
  });

  final BlindTile tile;
  final TileSize size;
  final bool showCategory;
  final bool asked;
  final bool chatting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tile.tile;
    final media = t.media;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: asked ? 0.42 : 1,
          duration: Motion.press,
          child: InsightTile(
            size: size,
            number: t.isAnswer ? null : t.headline,
            caption: t.isAnswer ? null : t.body,
            prompt: t.question,
            answer: t.isAnswer ? t.headline : null,
            tone: t.tone,
            isTrack: t.looksLikeTrack,
            music: t.music,
            mediaUrl: media?.stillUrl,
            videoUrl: media?.videoUrl,
            isLivePhoto: media?.kind == MediaKind.livePhoto,
            categoryGlyph: showCategory ? t.glyph : null,
            onTap: onTap,
          ),
        ),
        if (asked) const Positioned(top: 9, right: 9, child: _AskedMark()),
        // Lit while the sheet asking about it is up, so it is clear which
        // line the flick caught.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: chatting ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.tile),
                border: Border.all(color: AppColors.accent, width: 2.5),
                color: const Color(0x339B4487),
              ),
              child: const Center(
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.onAccent,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AskedMark extends StatelessWidget {
  const _AskedMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        'Asked',
        style: AppText.micro.copyWith(
          color: AppColors.onAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
