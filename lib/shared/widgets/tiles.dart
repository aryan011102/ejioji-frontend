import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'pressable.dart';

/// How much of the bento grid a tile takes.
enum TileSize { small, wide, tall, large }

extension TileSizeX on TileSize {
  /// Columns consumed, used to work out whether the last row has a hole for
  /// the photos tile to fill.
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
    this.isTrack = false,
    this.categoryGlyph,
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
  final bool hasMedia;
  final bool isTrack;

  /// Shown on your own wall only. A viewer is being introduced to a person and
  /// does not need a filing system on top of the photos.
  final String? categoryGlyph;

  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;
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
    final overMedia = hasMedia || isTrack;

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
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.tileEdge,
              width: selected ? 2.5 : 1,
            ),
            boxShadow: const [
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
                if (hasMedia)
                  // TODO(backend): a real photo, video or Live Photo goes here.
                  // Video autoplays muted; the mute and play controls belong on
                  // the tile, not in a viewer.
                  const ColoredBox(color: Color(0xFF1A1114)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: overMedia ? Scrims.media : Scrims.flat,
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
                if (categoryGlyph != null && !selected)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _Badge(child: Text(categoryGlyph!)),
                  ),
                if (selected)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: _Badge(
                      color: AppColors.fill,
                      child: Icon(Icons.check, size: 15, color: AppColors.label),
                    ),
                  ),
                if (isTrack) const Positioned(top: 12, right: 12, child: _ScanCode()),
                if (onMedia != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Pressable(
                      onTap: onMedia,
                      semanticLabel: 'Change what sits behind this',
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(
                          color: const Color(0x75000000),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_camera,
                              size: 15,
                              color: AppColors.label,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasMedia ? 'Change' : 'Add',
                              style: AppText.micro.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.label,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child, this.color = const Color(0x61000000)});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

/// The photos tile at the end of the wall.
///
/// One photo with dots, not a collage: a collage says "here are four small
/// things", and this is one thing you can swipe.
/// The photos tile that fills the hole at the end of the wall.
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
