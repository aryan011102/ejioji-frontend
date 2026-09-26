import '../widgets/tiles.dart';
import 'enums.dart';
import 'tile.dart';

/// How a tile is laid out and coloured.
///
/// The server sends a fact and a caption; it has no opinion about gradients or
/// grid spans, and it should not have one. So this is where a tile becomes a
/// tile: a size, a colour and a glyph, chosen here.
///
/// Two rules, both deliberate:
///
/// 1. **The same tile always looks the same.** The colour comes from the
///    category and the size from the content, never from the tile's position
///    in the list. A wall that reshuffles its colours when one tile is added
///    looks broken, and a tile someone recognises on their own profile has to
///    be the same tile on somebody else's.
/// 2. **A long value gets more room.** "3:12 AM" and "144" want different
///    boxes, and the number is the whole point of the tile: it must not be
///    shrunk to fit a square that was chosen before anyone looked at it.
extension TileLook on ProfileTile {
  String get tone => category.tone;

  String get glyph => category.glyph;

  /// How much of the grid this takes.
  ///
  /// An answer is somebody's sentence and always gets the full width. A
  /// derived tile is sized by how long its value is, because the value is set
  /// in large type and a name like "Prateek Kuhad" cannot be read at the size
  /// "62%" is set at.
  TileSize get tileSize {
    if (isAnswer) return TileSize.wide;

    final value = headline;
    if (value.length > 12) return TileSize.large;
    if (value.length > 6) return TileSize.wide;
    return TileSize.small;
  }

  /// Whether the value is a named thing rather than a quantity. The design
  /// treats those differently: a track or a show gets the record-sleeve
  /// treatment, a count does not.
  bool get isEntity => insight?.value.kind == ValueKind.entity;

  /// Only music entities get the track look, and only when there is something
  /// to name.
  bool get looksLikeTrack =>
      isEntity && category == TileCategory.music;
}

/// The colour family of a category. One per category, so a wall reads as a
/// set rather than a paint chart, and a tile quoted in a request or a chat
/// wears the same colour as the tile it came from.
extension CategoryTone on TileCategory {
  String get tone => switch (this) {
        TileCategory.foodDelivery => 'saffron',
        TileCategory.goingOut => 'indigo',
        TileCategory.shopping => 'rose',
        TileCategory.travel => 'cobalt',
        TileCategory.music => 'berry',
        TileCategory.social => 'teal',
        TileCategory.fitness => 'moss',
        TileCategory.watching => 'chilli',
        TileCategory.netflix => 'night',
        TileCategory.chatgpt => 'olive',
        TileCategory.home => 'cocoa',
        TileCategory.unknown => 'slate',
      };
}

/// The same, for a tile that has not been picked onto a profile yet.
///
/// The picker shows candidates, which are bare insights rather than profile
/// tiles, and they have to look identical to what they will become or the
/// preview is a lie.
extension CandidateLook on Insight {
  String get tone => category.tone;

  String get glyph => category.glyph;

  TileSize get tileSize {
    if (displayValue.length > 12) return TileSize.large;
    if (displayValue.length > 6) return TileSize.wide;
    return TileSize.small;
  }

  bool get looksLikeTrack =>
      value.kind == ValueKind.entity && category == TileCategory.music;

  /// How old the underlying data is, for the line that admits it.
  ///
  /// A profile built a year ago still claims today's taste. Saying when it was
  /// read is cheaper than pretending it is current.
  String get vintage {
    final days = DateTime.now().difference(computedAt).inDays;
    if (days < 1) return 'Read today';
    if (days == 1) return 'Read yesterday';
    if (days < 30) return 'Read $days days ago';
    if (days < 365) return 'Read ${days ~/ 30} months ago';
    return 'Read over a year ago';
  }
}
