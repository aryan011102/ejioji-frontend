import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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

/// One place on the plane: a block and a slot in it. The same tile can sit in
/// two places once a deal repeats, so the tile being held is a place.
typedef _Place = (int bx, int by, int slot);

/// A plane you drag in any direction, with no top, no end and no first tile.
///
/// Three things a finger can do (Aryan, 2026-10-04, after a fast flick and
/// then a tap-to-lift were both too much work):
///
/// - **Tap** a tile: a reminder of how to ask. It opened their profile until
///   2026-10-10; Blind no longer shows who someone is before they answer.
/// - **Touch a tile, rest a moment, slide left**: the tile slides to show
///   "Chat about this", as a profile tile does, and letting go past the mark
///   asks. One movement, no second step.
/// - **Touch and move at once**: the plane moves.
///
/// The moment of rest ([holdFor]) is what tells holding a tile from dragging
/// the plane; without it a swipe left and a drag left are the same gesture.
class BlindField extends StatefulWidget {
  const BlindField({
    required this.layout,
    required this.topInset,
    required this.onTap,
    required this.onChat,
    required this.onRunningLow,
    this.showCategory = true,
    super.key,
  });

  /// How long a finger rests on a tile before it holds the tile rather than
  /// the plane. Short: long enough to tell a deliberate touch from the start
  /// of a drag, short enough not to feel like waiting.
  static const holdFor = Duration(milliseconds: 180);

  final BlindLayout layout;

  /// What floats over the top edge (the tabs), so the first row starts below
  /// it rather than under it.
  final double topInset;

  final ValueChanged<BlindTile> onTap;
  final Future<void> Function(BlindTile) onChat;

  /// The plane has laid down most of what it has: time for the next page.
  final VoidCallback onRunningLow;

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

  /// The tile under a resting finger, and how far it has slid left.
  _Place? _held;
  double _slide = 0;
  bool _pastMark = false;

  /// The sheet is up: the slid tile holds where it is.
  bool _asking = false;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Animation<double>? _slideTo;

  late BlindGeometry _geo;

  @override
  void initState() {
    super.initState();
    _glide = createTicker(_onGlide);
    _settle.addListener(() {
      final to = _slideTo;
      if (to != null) setState(() => _slide = to.value);
    });
    _settle.addStatusListener((status) {
      // Back home with nothing being asked: nothing is held any more.
      if (status == AnimationStatus.completed && _slide == 0 && !_asking) {
        setState(() => _held = null);
      }
    });
  }

  @override
  void dispose() {
    _glide.dispose();
    _settle.dispose();
    super.dispose();
  }

  // ---- Moving the plane. ----

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

  void _onPanDown(DragDownDetails _) => _stopGlide();

  void _onPanUpdate(DragUpdateDetails d) {
    if (_asking) return;
    setState(() => _offset += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (_asking || v.distance < 120) return;
    _velocity = v;
    _lastTick = Duration.zero;
    _glide.start();
  }

  // ---- Holding a tile. ----

  /// How far left the tile must slide before letting go asks: about a third
  /// of it, but never more than a short thumb's travel on a wide tile.
  static double _markFor(double width) => math.min(width * 0.38, 110);

  double _widthOf(_Place p) => _geo.box(BlindLayout.slots[p.$3].$3).width;

  void _onHoldStart(_Place place) {
    if (_asking) return;
    _stopGlide();
    _settle.stop();
    HapticFeedback.selectionClick();
    setState(() {
      _held = place;
      _slide = 0;
      _pastMark = false;
    });
  }

  void _onHoldMove(_Place place, LongPressMoveUpdateDetails d) {
    if (_held != place || _asking) return;
    final width = _widthOf(place);
    // Only leftwards counts; a finger wandering right just closes it again.
    final next = (-d.offsetFromOrigin.dx).clamp(0.0, width * 0.85);
    final past = next >= _markFor(width);
    // One tap of the engine as it crosses into "let go and it asks".
    if (past != _pastMark) HapticFeedback.selectionClick();
    setState(() {
      _slide = next;
      _pastMark = past;
    });
  }

  void _onHoldEnd(_Place place, BlindTile tile, LongPressEndDetails d) {
    if (_held != place || _asking) return;
    final fling =
        d.velocity.pixelsPerSecond.dx < -700 && _slide > _widthOf(place) * 0.15;
    if (_pastMark || fling) {
      unawaited(_ask(place, tile));
    } else {
      _settleTo(0);
    }
    _pastMark = false;
  }

  void _settleTo(double target) {
    _slideTo = Tween(begin: _slide, end: target).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic),
    );
    unawaited(_settle.forward(from: 0));
  }

  Future<void> _ask(_Place place, BlindTile tile) async {
    HapticFeedback.mediumImpact();
    setState(() => _asking = true);
    // Rests open while the sheet is up, so it is plain which line is asked
    // about.
    _settleTo(math.min(_widthOf(place) * 0.5, 140));
    try {
      await widget.onChat(tile);
    } finally {
      if (mounted) {
        setState(() => _asking = false);
        _settleTo(0);
      }
    }
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
        Widget? heldChild;

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
              final place = (bx, by, k);
              final held = _held == place;
              final child = Positioned.fromRect(
                // Keyed by place and tile on the Stack's own child, so a
                // video keeps playing while the plane moves under it, and so
                // the held tile, moved to the top to draw over its
                // neighbours, keeps the recognizer that is holding it.
                key: ValueKey('$bx:$by:$k:${t.id}'),
                rect: rect,
                child: RawGestureDetector(
                  gestures: {
                    LongPressGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                            LongPressGestureRecognizer>(
                      () => LongPressGestureRecognizer(
                        duration: BlindField.holdFor,
                      ),
                      (r) {
                        r.onLongPressStart = (_) => _onHoldStart(place);
                        r.onLongPressMoveUpdate = (d) => _onHoldMove(place, d);
                        r.onLongPressEnd = (d) => _onHoldEnd(place, t, d);
                      },
                    ),
                  },
                  child: _Tile(
                    tile: t,
                    size: size,
                    showCategory: widget.showCategory,
                    held: held,
                    slide: held ? _slide : 0,
                    pastMark: held && (_pastMark || _asking),
                    onTap: () {
                      if (!_asking) widget.onTap(t);
                    },
                  ),
                ),
              );
              // The held tile is drawn last, so it slides over its neighbours
              // rather than under them.
              if (held) {
                heldChild = child;
              } else {
                children.add(child);
              }
            }
          }
        }
        if (heldChild != null) children.add(heldChild);

        if (widget.layout.runningLow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onRunningLow();
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: _onPanDown,
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
    required this.held,
    required this.slide,
    required this.pastMark,
    required this.onTap,
  });

  final BlindTile tile;
  final TileSize size;
  final bool showCategory;

  /// A finger is resting on it: it rises a little to say so.
  final bool held;

  /// How far left it has slid.
  final double slide;

  /// Slid far enough that letting go asks (or asking already).
  final bool pastMark;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tile.tile;
    final media = t.media;
    return AnimatedScale(
      scale: held ? 1.03 : 1,
      duration: Motion.press,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Under the tile, shown as it slides left: the way to ask. The
          // same look as a profile tile's "Chat about this".
          if (slide > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.tile),
              child: ColoredBox(
                color: pastMark ? AppColors.accent : AppColors.fill,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: slide,
                    child: Opacity(
                      opacity: (slide / 60).clamp(0.0, 1.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.onAccent,
                            size: 24,
                          ),
                          if (slide >= 96) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Chat about this',
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
          Transform.translate(
            offset: Offset(-slide, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.tile),
                boxShadow: held
                    ? const [
                        BoxShadow(
                          color: AppColors.glow,
                          blurRadius: 22,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: InsightTile(
                size: size,
                number: t.isAnswer ? null : t.headline,
                caption: t.isAnswer ? null : t.body,
                prompt: t.question,
                answer: t.isAnswer ? t.headline : null,
                tone: t.tone,
                isTrack: t.looksLikeTrack,
                music: t.music,
                poster: t.poster,
                mediaUrl: media?.stillUrl,
                videoUrl: media?.videoUrl,
                isLivePhoto: media?.kind == MediaKind.livePhoto,
                categoryGlyph: showCategory ? t.glyph : null,
                onTap: onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
