import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../models/archetype.dart';
import '../models/tile.dart' show ShowPoster, SongMusic;
import 'pressable.dart';

/// How much of the bento grid a tile takes.
enum TileSize { small, wide, tall, large }

extension TileSizeX on TileSize {
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
    this.music,
    this.poster,
    this.playMusic = true,
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

  /// The song a track tile is about, from Apple Music's catalog: its cover
  /// goes behind the tile when nothing of the person's own is there, and its
  /// preview plays from the button top right.
  final SongMusic? music;

  /// The show or film a tile is about, from TMDB: its poster goes behind the
  /// tile when nothing of the person's own is there and there is no song cover.
  final ShowPoster? poster;

  /// False where a preview would be in the way (the wobbling arrange wall):
  /// the cover still shows.
  final bool playMusic;

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
    // The person's own photo or video wins over the song's cover or a poster.
    final cover = mediaUrl == null && !hasMedia
        ? music?.artworkUrl ?? poster?.posterUrl
        : null;
    // Over a cover too, so a count about one artist stays readable on it.
    final overMedia = withMedia || isTrack || cover != null;
    // Any tile the server gave a song to: a song, or an artist, whose most
    // played song it is. A count about one artist is not a name tile, and plays
    // it all the same.
    final preview = playMusic ? music?.previewUrl : null;
    final trackWidth = preview != null ? 118.0 : (isTrack ? 84.0 : 0.0);

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
                    controlsRight: 10 + (selectable ? 36.0 : 0) + trackWidth,
                  )
                else if (mediaUrl != null)
                  _MediaImage(url: mediaUrl!)
                else if (cover != null)
                  _MediaImage(
                    url: cover,
                    fill: music?.artworkUrl != null ? music?.artworkBackground : null,
                  )
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
                if (preview != null)
                  Positioned(
                    top: 10,
                    right: selectable ? 46 : 10,
                    child: SongPreview(
                      // A new song is a new player, not a reused one.
                      key: ValueKey(preview),
                      url: preview,
                      title: music!.title,
                      appleMusicUrl: music!.appleMusicUrl,
                    ),
                  )
                else if (isTrack)
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
  const _MediaImage({required this.url, this.fill});

  final String url;

  /// Painted while it loads and if it never does. A song's cover brings its
  /// own colour, so the tile is the right colour before the image arrives.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(
              color: fill ?? const Color(0xFF1A1114),
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
      errorBuilder: (_, __, ___) =>
          ColoredBox(color: fill ?? const Color(0xFF1A1114)),
    );
  }
}

/// A song's thirty-second preview: play and pause, and the Apple Music badge
/// beside it, which is Apple's condition for using its previews.
///
/// Nothing loads until the first tap, so a wall of songs costs nothing until
/// someone wants to hear one. One song plays at a time: starting one stops
/// whichever was playing. Leaving the screen stops it too, since the player
/// goes with the tile.
class SongPreview extends StatefulWidget {
  const SongPreview({
    required this.url,
    required this.title,
    this.appleMusicUrl,
    super.key,
  });

  final String url;
  final String title;
  final String? appleMusicUrl;

  /// The preview playing now, anywhere in the app.
  static final ValueNotifier<Object?> _playing = ValueNotifier(null);

  @override
  State<SongPreview> createState() => _SongPreviewState();
}

class _SongPreviewState extends State<SongPreview> {
  VideoPlayerController? _audio;
  bool _loading = false;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    SongPreview._playing.addListener(_onOtherStarted);
  }

  void _onOtherStarted() {
    if (SongPreview._playing.value != this && _playing) _audio?.pause();
  }

  Future<void> _toggle() async {
    final audio = _audio;
    if (audio != null) {
      if (_playing) {
        await audio.pause();
      } else {
        SongPreview._playing.value = this;
        await audio.play();
      }
      return;
    }
    setState(() => _loading = true);
    final created = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await created.initialize();
    } catch (_) {
      // A moved link or no connection: the button goes, the cover stays.
      await created.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      await created.dispose();
      return;
    }
    created.addListener(_onTick);
    _audio = created;
    SongPreview._playing.value = this;
    await created.play();
    if (mounted) setState(() => _loading = false);
  }

  void _onTick() {
    final v = _audio!.value;
    // At the end it settles back to the start, ready to play again.
    if (v.isPlaying && v.duration > Duration.zero && v.position >= v.duration) {
      _audio!
        ..pause()
        ..seekTo(Duration.zero);
    }
    if (v.isPlaying != _playing && mounted) setState(() => _playing = v.isPlaying);
  }

  Future<void> _openAppleMusic() async {
    final url = widget.appleMusicUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    SongPreview._playing.removeListener(_onOtherStarted);
    if (SongPreview._playing.value == this) SongPreview._playing.value = null;
    _audio
      ?..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_failed)
          Pressable(
            onTap: _loading ? null : _toggle,
            semanticLabel: _playing
                ? 'Pause ${widget.title}'
                : 'Play a preview of ${widget.title}',
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Color(0x6B000000),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: AppColors.label,
                      ),
                    )
                  : Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 19,
                      color: AppColors.label,
                    ),
            ),
          ),
        const SizedBox(width: 8),
        Pressable(
          onTap: widget.appleMusicUrl == null ? null : _openAppleMusic,
          semanticLabel: 'Open in Apple Music',
          child: Container(
            height: 24,
            padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
            decoration: BoxDecoration(
              color: const Color(0xEBFFFFFF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apple, size: 14, color: Color(0xFF1A1116)),
                const SizedBox(width: 2),
                Text(
                  'Music',
                  style: AppText.micro.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1116),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

/// The scannable code on a track tile whose song Apple's catalog does not
/// have, so there is no preview to play in its place.
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
        final slots = pack([for (final i in items) i.size]);
        final rows = slots.fold<int>(0, (m, s) => m > s.bottom ? m : s.bottom);
        return SizedBox(
          height: rows * rowHeight + (rows - 1).clamp(0, 99) * gap,
          child: Stack(
            children: [
              for (final (i, s) in slots.indexed)
                Positioned(
                  left: s.col * (cell + gap),
                  top: s.row * (rowHeight + gap),
                  width: s.w * cell + (s.w - 1) * gap,
                  height: s.h * rowHeight + (s.h - 1) * gap,
                  child: items[i].child,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Where each tile goes, in the order given, with no gaps (Aryan,
  /// 2026-10-01).
  ///
  /// Dense first-fit, then every hole the packing left is covered by
  /// stretching a neighbour into it: sideways first (a lone tile becomes
  /// wide), then down from the tile above, then up from the tile below. A
  /// hole none of those can reach always sits beside a tall tile, which is
  /// then cut to the row the hole is not in, and a row left empty closes up.
  /// A tile is never more than two by two, and its type keeps the size it
  /// asked for. Checked for every order of up to eight tiles.
  static List<Slot> pack(List<TileSize> sizes) {
    final slots = <Slot>[];
    // Tiles cut to one row, which may still widen but never grow back down
    // or up into the row they were cut from; that is what makes this end.
    final cut = <int>{};

    Map<(int, int), int> grid() => {
          for (final (i, s) in slots.indexed)
            for (var r = s.row; r < s.bottom; r++)
              for (var c = s.col; c < s.col + s.w; c++) (r, c): i,
        };

    bool free(Map<(int, int), int> g, int row, int col, int w, int h) {
      for (var r = row; r < row + h; r++) {
        for (var c = col; c < col + w; c++) {
          if (c > 1 || g.containsKey((r, c))) return false;
        }
      }
      return true;
    }

    int rows() => slots.fold<int>(0, (m, s) => m > s.bottom ? m : s.bottom);

    for (final size in sizes) {
      final w = size.crossAxisCells;
      final h = size.mainAxisCells;
      final g = grid();
      var row = 0;
      int? col;
      while (col == null) {
        for (var c = 0; c + w <= 2; c++) {
          if (free(g, row, c, w, h)) {
            col = c;
            break;
          }
        }
        if (col == null) row++;
      }
      slots.add(Slot(row: row, col: col, w: w, h: h));
    }

    // One stretch into a hole, or false when none is left to make.
    bool grow() {
      final g = grid();
      for (var r = 0; r < rows(); r++) {
        for (var c = 0; c < 2; c++) {
          if (g.containsKey((r, c))) continue;
          if (g[(r, 1 - c)] case final i?) {
            final s = slots[i];
            if (s.w == 1 && free(g, s.row, c, 1, s.h)) {
              slots[i] = Slot(row: s.row, col: 0, w: 2, h: s.h);
              return true;
            }
          }
          if (g[(r - 1, c)] case final i? when !cut.contains(i)) {
            final s = slots[i];
            if (s.h == 1 && free(g, r, s.col, s.w, 1)) {
              slots[i] = Slot(row: s.row, col: s.col, w: s.w, h: 2);
              return true;
            }
          }
          if (g[(r + 1, c)] case final i? when !cut.contains(i)) {
            final s = slots[i];
            if (s.h == 1 && free(g, r, s.col, s.w, 1)) {
              slots[i] = Slot(row: r, col: s.col, w: s.w, h: 2);
              return true;
            }
          }
        }
      }
      return false;
    }

    while (true) {
      while (grow()) {}
      // Close up any row left empty.
      var g = grid();
      for (var r = rows() - 1; r >= 0; r--) {
        if (!g.containsKey((r, 0)) && !g.containsKey((r, 1))) {
          for (final (i, s) in slots.indexed) {
            if (s.row > r) {
              slots[i] = Slot(row: s.row - 1, col: s.col, w: s.w, h: s.h);
            }
          }
        }
      }
      g = grid();
      (int, int)? hole;
      for (var r = 0; r < rows() && hole == null; r++) {
        for (var c = 0; c < 2; c++) {
          if (!g.containsKey((r, c))) {
            hole = (r, c);
            break;
          }
        }
      }
      if (hole == null) return slots;
      // The cell beside it is a tall tile: cut it to the row the hole is
      // not in.
      final (r, c) = hole;
      final i = g[(r, 1 - c)]!;
      final s = slots[i];
      slots[i] = Slot(row: s.row, col: s.col, w: s.w, h: 1);
      cut.add(i);
    }
  }
}

/// A tile's place on the wall, in cells.
class Slot {
  const Slot({required this.row, required this.col, required this.w, required this.h});

  final int row;
  final int col;
  final int w;
  final int h;

  int get bottom => row + h;

  @override
  bool operator ==(Object other) =>
      other is Slot &&
      other.row == row &&
      other.col == col &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(row, col, w, h);

  @override
  String toString() => 'Slot($row, $col, ${w}x$h)';
}

/// The photos tile, first on the wall so it is always in the top row.
///
/// One photo with dots, not a collage: a collage says "here are four small
/// things", and this is one thing you can swipe.
///
/// With an [archetype], a tap turns it over to "who your data thinks you are"
/// (Aryan's call, 2026-10-10), and another turns it back. Swiping still pages
/// the photos, and the page is kept while it is turned over.
///
/// The URLs are signed and expire, so a failure here is ordinary rather than
/// exceptional: it falls back to a plain fill instead of Flutter's grey box
/// with a crossed-out icon, which on a profile reads as a broken person.
class PhotosTile extends StatefulWidget {
  const PhotosTile({
    required this.photoUrls,
    this.archetype,
    this.theirs = false,
    super.key,
  });

  final List<String> photoUrls;

  /// What the back says. Null leaves the tile photos only.
  final Archetype? archetype;

  /// Somebody else's profile: the back says "their data", not "your data".
  final bool theirs;

  @override
  State<PhotosTile> createState() => _PhotosTileState();
}

class _PhotosTileState extends State<PhotosTile>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;

  /// Built in initState: a ticker first touched in dispose is created during
  /// unmount, which throws, and a tile with no archetype never touches it
  /// before then.
  late final AnimationController _turn;

  @override
  void initState() {
    super.initState();
    _turn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
  }

  @override
  void dispose() {
    _turn.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    final over = _turn.status == AnimationStatus.forward ||
        _turn.status == AnimationStatus.completed;
    unawaited(over ? _turn.reverse() : _turn.forward());
  }

  @override
  Widget build(BuildContext context) {
    final archetype = widget.archetype;
    if (archetype == null) return _photos(turns: false);
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          final angle = Curves.easeInOutCubic.transform(_turn.value) * math.pi;
          final back = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Kept while turned over, so it turns back to the same photo.
                Visibility(
                  visible: !back,
                  maintainState: true,
                  child: _photos(turns: true),
                ),
                if (back)
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: ArchetypeFace(
                      archetype: archetype,
                      theirs: widget.theirs,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _photos({required bool turns}) {
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
          // That there is a back to turn to.
          if (turns)
            Positioned(
              top: 10,
              right: 10,
              child: _Badge(
                child: Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppColors.label,
                  semanticLabel: widget.theirs
                      ? 'Tap to see who their data thinks they are'
                      : 'Tap to see who your data thinks you are',
                ),
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

/// "Who your data thinks you are", written out: the back of the photo tile,
/// and each choice on the archetype page. The title only: the line under it
/// came off on 2026-10-10 (Aryan: too wordy to read on a tile). On somebody
/// else's profile the label reads "Who their data thinks they are".
///
/// Drawn the way a prompt answer is ([InsightTile] with a prompt): the label in
/// small capitals over the title, both at the foot of the tile, at the same
/// sizes, so the back of the photo reads as one more tile on the wall.
class ArchetypeFace extends StatelessWidget {
  const ArchetypeFace({
    required this.archetype,
    this.selected = false,
    this.selectable = false,
    this.theirs = false,
    super.key,
  });

  static const label = 'Who your data thinks you are';
  static const theirLabel = 'Who their data thinks they are';

  /// Somebody else's: the label speaks about them, not to them.
  final bool theirs;

  final Archetype archetype;

  /// Chosen in the picker: the same ring a picked tile has.
  final bool selected;

  /// One of the choices on the archetype page (Aryan, 2026-10-11): the title
  /// alone, like any other tile, with the same circle at the top right that
  /// every tile being picked has. The label is the page's own title there, so
  /// four copies of it say nothing.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final face = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.tile),
        gradient: TileTones.indigo,
        border: Border.all(color: AppColors.tileEdge, width: 0.67),
        boxShadow: selected
            ? const [
                BoxShadow(color: AppColors.accent, spreadRadius: 4.5),
                BoxShadow(color: Color(0xFF000000), spreadRadius: 2),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!selectable) ...[
              Text(
                (theirs ? theirLabel : label).toUpperCase(),
                style: AppText.micro.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: const Color(0xA8FFFFFF),
                ),
              ),
              const SizedBox(height: 5),
            ],
            Text(
              archetype.title,
              style: AppText.bodyStrong.copyWith(
                fontSize: 17,
                height: 22 / 17,
                color: AppColors.label,
              ),
            ),
          ],
        ),
      ),
    );
    if (!selectable) return face;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        face,
        Positioned(top: 10, right: 10, child: _Radio(on: selected)),
      ],
    );
  }
}
