import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'pressable.dart';

/// How much of the bento grid a tile takes.
enum TileSize { small, wide, tall, large }

extension TileSizeX on TileSize {
  /// Columns consumed, used to size the photos tile so the wall's rows come
  /// out even.
  int get columns => switch (this) {
        TileSize.small || TileSize.tall => 1,
        TileSize.wide || TileSize.large => 2,
      };

  int get crossAxisCells => switch (this) {
        TileSize.small || TileSize.tall => 1,
        TileSize.wide || TileSize.large => 2,
      };

  int get mainAxisCells => switch (this) {
        TileSize.small || TileSize.wide => 1,
        TileSize.tall || TileSize.large => 2,
      };

  static TileSize parse(String? s) => switch (s) {
        'w' => TileSize.wide,
        't' => TileSize.tall,
        'l' => TileSize.large,
        _ => TileSize.small,
      };
}

/// One insight, as it appears on a wall.
///
/// The number is the tile. Everything else — the caption, the scrim, the
/// source glyph — exists to keep the number readable, which is why the type
/// size is a function of how long the number is: a wrapped number stops
/// reading as a number.
class InsightTile extends StatelessWidget {
  const InsightTile({
    required this.size,
    this.number,
    this.caption,
    this.prompt,
    this.answer,
    this.tone,
    this.hasMedia = false,
    this.mediaUrl,
    this.videoUrl,
    this.isLivePhoto = false,
    this.mediaBusy = false,
    this.isTrack = false,
    this.categoryGlyph,
    this.selectable = false,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    this.onMedia,
    super.key,
  });

  final TileSize size;
  final String? number;
  final String? caption;

  /// A prompt answer is an insight too — it just came from a question rather
  /// than a receipt, and it is the only tile written in the first person.
  final String? prompt;
  final String? answer;

  final String? tone;

  /// A placeholder for media with no URL yet (the demo walls).
  final bool hasMedia;

  /// The still behind the tile: the photo, or a video's poster frame. It
  /// replaces the tile's colour; the number and caption stay on top.
  final String? mediaUrl;

  /// The motion, for a video or a live photo. A video plays in the tile, muted
  /// and looping; a live photo plays its motion while pressed, as on iOS.
  final String? videoUrl;
  final bool isLivePhoto;

  /// An upload for this tile is in flight.
  final bool mediaBusy;

  final bool isTrack;

  /// Shown on your own wall only. A viewer is being introduced to a person and
  /// does not need a filing system on top of the photos.
  final String? categoryGlyph;

  /// Shows the radio on the top right. Only where tiles are being picked.
  final bool selectable;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  /// Shows the camera on the top left, which opens the sheet that puts a
  /// photo or video behind the tile. Only where tiles are being picked or
  /// edited; a viewer has nothing to change.
  final VoidCallback? onMedia;

  double get _numberSize {
    final base = switch (size) {
      TileSize.small => 34.0,
      TileSize.wide => 40.0,
      TileSize.tall => 38.0,
      TileSize.large => 52.0,
    };
    final n = number?.length ?? 0;
    if (n > 7) return base * 0.68;
    if (n > 4) return base * 0.86;
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final withMedia = hasMedia || mediaUrl != null;
    final overMedia = withMedia || isTrack;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: dimmed ? 0.62 : 1,
      child: Pressable(
        onTap: onTap,
        scale: 0.985,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.tile),
            gradient: TileTones.of(tone),
            border: Border.all(color: AppColors.tileEdge, width: 0.67),
            // Picked reads as a ring set off the tile by a hairline of black,
            // so it stays visible against a tile of any colour.
            boxShadow: selected
                ? const [
                    BoxShadow(color: AppColors.accent, spreadRadius: 4.5),
                    BoxShadow(color: Color(0xFF000000), spreadRadius: 2),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0xB3000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.tile),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (mediaUrl != null && videoUrl != null)
                  _TileMotion(
                    // A new clip is a new player, not a reused one.
                    key: ValueKey(videoUrl),
                    stillUrl: mediaUrl!,
                    videoUrl: videoUrl!,
                    live: isLivePhoto,
                    // Where a tap picks the tile, it cannot also pause.
                    tapToPause: onTap == null,
                    // Clear of whatever already sits top right.
                    controlsRight: 10 +
                        (selectable ? 36.0 : 0) +
                        (isTrack ? 84.0 : 0),
                  )
                else if (mediaUrl != null)
                  _MediaImage(url: mediaUrl!)
                else if (hasMedia)
                  const ColoredBox(color: Color(0xFF1A1114)),
                // Paint only: the scrim covers the whole tile and must not take
                // the taps meant for the controls under it.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: overMedia ? Scrims.media : Scrims.flat,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: prompt != null
                        ? [
                            Text(
                              prompt!.toUpperCase(),
                              style: AppText.micro.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: const Color(0xA8FFFFFF),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              answer ?? '',
                              style: AppText.bodyStrong.copyWith(
                                fontSize: 17,
                                height: 22 / 17,
                                color: AppColors.label,
                              ),
                            ),
                          ]
                        : [
                            Text(
                              number ?? '',
                              style: AppText.tileNumber(_numberSize),
                            ),
                            const SizedBox(height: 6),
                            Text(caption ?? '', style: AppText.tileCaption),
                          ],
                  ),
                ),
                if (onMedia != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _MediaButton(
                      onTap: mediaBusy ? null : onMedia,
                      busy: mediaBusy,
                      replacing: withMedia,
                    ),
                  )
                else if (categoryGlyph != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _Badge(child: Text(categoryGlyph!)),
                  ),
                if (isTrack)
                  Positioned(
                    top: 12,
                    right: selectable ? 46 : 12,
                    child: const _ScanCode(),
                  ),
                if (selectable)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _Radio(on: selected),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The camera on a tile, or the swap arrows once something is behind it.
class _MediaButton extends StatelessWidget {
  const _MediaButton({
    required this.onTap,
    required this.busy,
    required this.replacing,
  });

  final VoidCallback? onTap;
  final bool busy;
  final bool replacing;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: busy
          ? 'Uploading'
          : replacing
              ? 'Change what sits behind this'
              : 'Put a photo or video behind this',
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          // Darker over a photo, lighter over a colour: either way it has to
          // lift off what is under it.
          color: replacing ? const Color(0x6B000000) : const Color(0x33FFFFFF),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: AppColors.label,
                ),
              )
            : Icon(
                replacing ? Icons.sync_rounded : Icons.photo_camera,
                size: replacing ? 19 : 17,
                color: AppColors.label,
              ),
      ),
    );
  }
}

/// The picked-or-not radio on a tile being picked.
class _Radio extends StatelessWidget {
  const _Radio({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? AppColors.label : const Color(0x24000000),
        border: on
            ? null
            : Border.all(color: const Color(0xB8FFFFFF), width: 1.33),
        boxShadow: on
            ? const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: on
          ? const Icon(Icons.check_rounded, size: 17, color: Color(0xFF5E2750))
          : null,
    );
  }
}

/// A video or a live photo, playing in the tile itself.
///
/// A video autoplays muted and loops, with mute and play on the tile: sound
/// from a wall nobody asked to hear is how an app gets deleted on a train. A
/// live photo sits still, with its badge, and plays its motion while pressed
/// or once when the badge is tapped, then settles back on the still.
///
/// Until the player is ready the still is shown, with the image's own loading
/// spinner, so a slow connection looks like a photo rather than a black box.
class _TileMotion extends StatefulWidget {
  const _TileMotion({
    required this.stillUrl,
    required this.videoUrl,
    required this.live,
    required this.tapToPause,
    required this.controlsRight,
    super.key,
  });

  final String stillUrl;
  final String videoUrl;
  final bool live;
  final bool tapToPause;
  final double controlsRight;

  @override
  State<_TileMotion> createState() => _TileMotionState();
}

class _TileMotionState extends State<_TileMotion> {
  late final VideoPlayerController _video =
      VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
  bool _ready = false;
  bool _failed = false;
  bool _muted = true;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _video.addListener(_onTick);
    _start();
  }

  Future<void> _start() async {
    try {
      await _video.initialize();
      await _video.setVolume(0);
      if (!widget.live) {
        await _video.setLooping(true);
        await _video.play();
      }
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // An expired URL or a codec the phone lacks: the still stays up, which
      // is what the tile looked like before anyone added motion.
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onTick() {
    final v = _video.value;
    final playing = v.isPlaying;
    // A live photo plays once and settles back on its still.
    if (widget.live && playing && v.position >= v.duration) {
      _video
        ..pause()
        ..seekTo(Duration.zero);
    }
    if (playing != _playing && mounted) setState(() => _playing = playing);
  }

  void _togglePlay() => _playing ? _video.pause() : _video.play();

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _video.setVolume(_muted ? 0 : 1);
  }

  Future<void> _playLive() async {
    if (!_ready) return;
    await _video.seekTo(Duration.zero);
    await _video.play();
  }

  void _stopLive() {
    if (!widget.live) return;
    _video
      ..pause()
      ..seekTo(Duration.zero);
  }

  @override
  void dispose() {
    _video
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showVideo = _ready && !_failed && (!widget.live || _playing);
    final size = _video.value.size;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.tapToPause && !widget.live && _ready ? _togglePlay : null,
      onLongPressStart: widget.live ? (_) => _playLive() : null,
      onLongPressEnd: widget.live ? (_) => _stopLive() : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _MediaImage(url: widget.stillUrl),
          if (showVideo)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(_video),
              ),
            ),
          if (_ready && !_failed)
            Positioned(
              top: 10,
              right: widget.controlsRight,
              child: widget.live
                  ? _RoundControl(
                      icon: Icons.motion_photos_on_outlined,
                      label: 'Play the live photo',
                      onTap: _playLive,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_playing) ...[
                          _RoundControl(
                            icon: Icons.play_arrow_rounded,
                            label: 'Play',
                            onTap: _togglePlay,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _RoundControl(
                          icon: _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          label: _muted ? 'Unmute' : 'Mute',
                          onTap: _toggleMute,
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

/// A 30pt dark circle with one glyph: the video and live photo controls.
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Color(0x6B000000),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.label),
      ),
    );
  }
}

/// The photo behind a tile. The URL is signed and can expire, and a slow
/// connection is ordinary, so both have an answer that is not Flutter's grey
/// box: a spinner while it loads, and the plain dark fill if it never does.
class _MediaImage extends StatelessWidget {
  const _MediaImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(
              color: const Color(0xFF1A1114),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.label2,
                    value: progress.expectedTotalBytes == null
                        ? null
                        : progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!,
                  ),
                ),
              ),
            ),
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1114)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 27,
        height: 27,
        decoration: const BoxDecoration(
          color: Color(0x61000000),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      );
}

/// The scannable code on a track tile. It keeps the album art and the code and
/// loses the player, because a page cannot borrow the listener's account.
class _ScanCode extends StatelessWidget {
  const _ScanCode();

  static const _bars = [7, 12, 5, 14, 9, 4, 11, 6, 13, 8, 5, 10, 7, 12, 4];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xEBFFFFFF),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final h in _bars)
            Container(
              width: 1.6,
              height: h.toDouble(),
              margin: const EdgeInsets.symmetric(horizontal: 0.75),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1116),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}

/// The bento wall.
///
/// Two columns on 172pt rows with dense packing, so a small tile backfills the
/// hole a wide one leaves rather than starting a new row.
class BentoGrid extends StatelessWidget {
  const BentoGrid({required this.children, this.padding, super.key});

  final List<BentoItem> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(Insets.gutter, 16, Insets.gutter, 0),
      child: StaggeredGrid(items: children),
    );
  }
}

class BentoItem {
  const BentoItem({required this.size, required this.child});

  final TileSize size;
  final Widget child;
}

/// A small two-column dense packer.
///
/// Flutter has no first-party dense staggered grid, and pulling a package in
/// for eighty lines of layout is not worth the dependency surface.
class StaggeredGrid extends StatelessWidget {
  const StaggeredGrid({
    required this.items,
    this.rowHeight = 172,
    this.gap = 12,
    super.key,
  });

  final List<BentoItem> items;
  final double rowHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - gap) / 2;
        final occupied = <int, List<bool>>{};
        final placed = <Widget>[];
        var maxRow = 0;

        bool free(int row, int col, int w, int h) {
          for (var r = row; r < row + h; r++) {
            final line = occupied[r] ??= [false, false];
            for (var c = col; c < col + w; c++) {
              if (c > 1 || line[c]) return false;
            }
          }
          return true;
        }

        void take(int row, int col, int w, int h) {
          for (var r = row; r < row + h; r++) {
            final line = occupied[r] ??= [false, false];
            for (var c = col; c < col + w; c++) {
              line[c] = true;
            }
          }
          maxRow = maxRow > row + h ? maxRow : row + h;
        }

        for (final item in items) {
          final w = item.size.crossAxisCells;
          final h = item.size.mainAxisCells;
          var row = 0;
          var col = 0;
          var found = false;
          while (!found && row < 200) {
            for (col = 0; col + w <= 2; col++) {
              if (free(row, col, w, h)) {
                found = true;
                break;
              }
            }
            if (!found) row++;
          }
          take(row, col, w, h);
          placed.add(
            Positioned(
              left: col * (cell + gap),
              top: row * (rowHeight + gap),
              width: w * cell + (w - 1) * gap,
              height: h * rowHeight + (h - 1) * gap,
              child: item.child,
            ),
          );
        }

        return SizedBox(
          height: maxRow * rowHeight + (maxRow - 1).clamp(0, 99) * gap,
          child: Stack(children: placed),
        );
      },
    );
  }
}

/// The photos tile, first on the wall so it is always in the top row.
///
/// One photo with dots, not a collage: a collage says "here are four small
/// things", and this is one thing you can swipe.
///
/// The URLs are signed and expire, so a failure here is ordinary rather than
/// exceptional: it falls back to a plain fill instead of Flutter's grey box
/// with a crossed-out icon, which on a profile reads as a broken person.
class PhotosTile extends StatefulWidget {
  const PhotosTile({required this.photoUrls, super.key});

  final List<String> photoUrls;

  @override
  State<PhotosTile> createState() => _PhotosTileState();
}

class _PhotosTileState extends State<PhotosTile> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.tile),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photoUrls.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Image.network(
              widget.photoUrls[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.photoEmpty),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.photoUrls.length; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? AppColors.label
                          : const Color(0x66FFFFFF),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
