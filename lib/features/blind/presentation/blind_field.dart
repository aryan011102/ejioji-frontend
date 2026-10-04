import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
/// two places once a deal repeats, so a lifted tile is a place, not a tile.
typedef _Place = (int bx, int by, int slot);

/// A plane you drag in any direction, with no top, no end and no first tile.
///
/// Tap and swipe (Aryan, 2026-10-04, replacing a fast flick that was too hard
/// to hit): a tap lifts a tile and stops the plane; the lifted tile then
/// slides right, at any speed, to show "Chat about this" under it, and letting
/// go past the mark asks. A tap on the lifted tile opens whose it is. A tap or
/// a drag anywhere else puts it back. The plane itself never has to tell a
/// swipe from a move, because only a lifted tile swipes.
class BlindField extends StatefulWidget {
  const BlindField({
    required this.layout,
    required this.topInset,
    required this.bottomInset,
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

  /// What floats over the bottom (the tab bar), so the lifted tile's hint
  /// sits above it.
  final double bottomInset;

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

  /// The lifted tile, if any, and how far it has slid right.
  _Place? _lifted;
  double _slide = 0;
  bool _sliding = false;
  bool _pastMark = false;

  /// Asking: the sheet is up, and the slid tile holds where it is.
  bool _asking = false;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
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

  void _onPanStart(DragStartDetails d) {
    _stopGlide();
    _velocity = Offset.zero;
    final lifted = _lifted;
    if (lifted != null && !_asking && _placeAt(d.localPosition) == lifted) {
      _settle.stop();
      _sliding = true;
      return;
    }
    // A drag anywhere else puts the lifted tile back and moves the plane.
    if (lifted != null && !_asking) _drop();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_sliding) {
      final width = _liftedWidth;
      final next = (_slide + d.delta.dx).clamp(0.0, width * 0.85);
      final past = next >= _markFor(width);
      // One tap of the engine as it crosses into "let go and it asks".
      if (past != _pastMark) HapticFeedback.selectionClick();
      setState(() {
        _slide = next;
        _pastMark = past;
      });
      return;
    }
    if (_asking) return;
    setState(() => _offset += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (_sliding) {
      _sliding = false;
      final fling = v.dx > 700 && _slide > _liftedWidth * 0.15;
      if (_pastMark || fling) {
        unawaited(_ask());
      } else {
        _settleTo(0);
      }
      _pastMark = false;
      return;
    }
    if (_asking || v.distance < 120) return;
    _velocity = v;
    _lastTick = Duration.zero;
    _glide.start();
  }

  // ---- The lifted tile. ----

  /// How far right the tile must slide before letting go asks: about a third
  /// of it, but never more than a short thumb's travel on a wide tile.
  static double _markFor(double width) => math.min(width * 0.38, 110);

  double get _liftedWidth {
    final lifted = _lifted;
    if (lifted == null) return 1;
    return _geo.box(BlindLayout.slots[lifted.$3].$3).width;
  }

  BlindTile? _tileOf(_Place p) {
    final tiles = widget.layout.block(p.$1, p.$2);
    return p.$3 < tiles.length ? tiles[p.$3] : null;
  }

  void _onTileTap(_Place place, BlindTile tile) {
    if (_asking) return;
    if (_lifted == place) {
      widget.onOpen(tile);
      return;
    }
    _stopGlide();
    HapticFeedback.selectionClick();
    _settle.stop();
    setState(() {
      _lifted = place;
      _slide = 0;
    });
  }

  void _drop() {
    _settle.stop();
    setState(() {
      _lifted = null;
      _slide = 0;
      _sliding = false;
      _pastMark = false;
    });
  }

  void _settleTo(double target) {
    _slideTo = Tween(begin: _slide, end: target).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic),
    );
    unawaited(_settle.forward(from: 0));
  }

  Future<void> _ask() async {
    final place = _lifted;
    final tile = place == null ? null : _tileOf(place);
    if (tile == null) {
      _drop();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _asking = true);
    // Rests open while the sheet is up, so it is plain which line is asked
    // about.
    _settleTo(_liftedWidth * 0.5);
    try {
      await widget.onChat(tile);
    } finally {
      if (mounted) {
        setState(() => _asking = false);
        _drop();
      }
    }
  }

  /// The place under a point on screen, if any (a gap is no place).
  _Place? _placeAt(Offset local) {
    final p = local - _offset;
    final bx = (p.dx / _geo.blockWidth).floor();
    final by = (p.dy / _geo.blockHeight).floor();
    final q = p - Offset(bx * _geo.blockWidth, by * _geo.blockHeight);
    for (var k = 0; k < BlindLayout.slots.length; k++) {
      final (col, row, size) = BlindLayout.slots[k];
      final rect = Offset(col * _geo.step, row * _geo.step) & _geo.box(size);
      if (rect.contains(q)) return (bx, by, k);
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
        Widget? liftedChild;

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
              final lifted = _lifted == place;
              final child = Positioned.fromRect(
                rect: rect,
                child: _Tile(
                  // Keyed by place and tile, so a video keeps playing while
                  // the plane moves under it.
                  key: ValueKey('$bx:$by:$k:${t.id}'),
                  tile: t,
                  size: size,
                  showCategory: widget.showCategory,
                  asked: widget.asked.contains(t.person.userId),
                  lifted: lifted,
                  receded: _lifted != null && !lifted,
                  slide: lifted ? _slide : 0,
                  pastMark: lifted && (_pastMark || _asking),
                  onTap: () => _onTileTap(place, t),
                ),
              );
              // The lifted tile is drawn last, so its shadow falls on its
              // neighbours rather than under them.
              if (lifted) {
                liftedChild = child;
              } else {
                children.add(child);
              }
            }
          }
        }
        if (liftedChild != null) children.add(liftedChild);

        if (widget.layout.runningLow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onRunningLow();
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // A tap in a gap puts the lifted tile back.
          onTap: _lifted != null && !_asking ? _drop : null,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: ClipRect(
            child: Stack(
              children: [
                ...children,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: widget.bottomInset,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _lifted != null && !_asking ? 1 : 0,
                      duration: Motion.fade,
                      child: const Center(child: _LiftHint()),
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

/// One tile on the plane: the profile's own tile, so the line met here is the
/// line on their profile, not a teaser written for this screen.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.tile,
    required this.size,
    required this.showCategory,
    required this.asked,
    required this.lifted,
    required this.receded,
    required this.slide,
    required this.pastMark,
    required this.onTap,
    super.key,
  });

  final BlindTile tile;
  final TileSize size;
  final bool showCategory;
  final bool asked;

  /// Picked up: a little larger, lit, and the one thing that can slide.
  final bool lifted;

  /// Another tile is lifted: this one steps back so that one reads.
  final bool receded;

  /// How far right the lifted tile has slid.
  final double slide;

  /// Slid far enough that letting go asks (or asking already).
  final bool pastMark;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tile.tile;
    final media = t.media;
    final face = InsightTile(
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
    );

    return AnimatedScale(
      scale: lifted ? 1.04 : 1,
      duration: Motion.page,
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: receded ? 0.45 : (asked ? 0.42 : 1),
        duration: Motion.fade,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // Under the tile, shown as it slides right: the way to ask.
            if (lifted && slide > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.tile),
                child: ColoredBox(
                  color: pastMark ? AppColors.accent : AppColors.fill,
                  child: Align(
                    alignment: Alignment.centerLeft,
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
              offset: Offset(slide, 0),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.tile),
                  border: lifted
                      ? Border.all(color: AppColors.accent, width: 2)
                      : null,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.tile),
                    boxShadow: lifted
                        ? const [
                            BoxShadow(
                              color: AppColors.glow,
                              blurRadius: 28,
                              offset: Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  child: face,
                ),
              ),
            ),
            if (asked) const Positioned(top: 9, right: 9, child: _AskedMark()),
          ],
        ),
      ),
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

/// What a lifted tile can do, said once it is lifted rather than taught up
/// front.
class _LiftHint extends StatelessWidget {
  const _LiftHint();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 40,
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassEdge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.swipe_right_alt_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Swipe right to chat · tap to open',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.footnote.copyWith(
                    color: AppColors.label,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
