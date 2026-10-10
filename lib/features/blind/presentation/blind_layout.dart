import 'dart:math' as math;

import '../../../shared/models/blind.dart';
import '../../../shared/widgets/tiles.dart';

/// Where tiles sit on Go blind's plane.
///
/// The plane is a lattice of blocks, four columns by six rows, laid edge to
/// edge with no end in any direction. Every block has the same slots; what
/// differs is which tiles are in them. A block is filled the first time it
/// comes into view, from the next tiles in the deal, and remembered, so
/// dragging away and back finds the same tiles where they were.
///
/// Two sizes and their turned-up twin, never the big square (Aryan,
/// 2026-10-04): it took a third of the screen for one line, and on a surface
/// you move through that is a wall in the way.
class BlindLayout {
  BlindLayout(List<BlindTile> tiles) : _tiles = [...tiles];

  static const cols = 4;
  static const rows = 6;

  /// Column, row, size. Eighteen tiles, no overlaps, no holes.
  static const slots = <(int, int, TileSize)>[
    (0, 0, TileSize.wide), (2, 0, TileSize.small), (3, 0, TileSize.small),
    (0, 1, TileSize.small), (1, 1, TileSize.tall), (2, 1, TileSize.wide),
    (0, 2, TileSize.small), (2, 2, TileSize.small), (3, 2, TileSize.small),
    (0, 3, TileSize.wide), (2, 3, TileSize.small), (3, 3, TileSize.tall),
    (0, 4, TileSize.small), (1, 4, TileSize.small), (2, 4, TileSize.small),
    (0, 5, TileSize.small), (1, 5, TileSize.wide), (3, 5, TileSize.small),
  ];

  /// How far ahead a slot looks for a tile that fits it before taking
  /// whatever is next. Small enough that the deal's order mostly holds.
  static const _lookahead = 10;

  final List<BlindTile> _tiles;
  final Map<(int, int), List<BlindTile>> _blocks = {};

  /// Positions in [_tiles] not yet laid down, in deal order.
  final List<int> _waiting = [];
  int _next = 0;

  /// How many tiles have been laid down, counting repeats.
  int _laid = 0;

  int get length => _tiles.length;

  /// More of the same deal. Blocks already filled keep what they hold.
  void add(List<BlindTile> more) => _tiles.addAll(more);

  /// Takes every tile of one person off the plane: someone asked from here
  /// (Aryan's call, 2026-10-10), so they are not asked twice. Each place they
  /// held is filled from the deal, so the plane keeps its shape and has no
  /// holes; every other tile stays where it was.
  void removePerson(String userId) {
    bool theirs(BlindTile t) => t.person.userId == userId;
    if (!_tiles.any(theirs)) return;

    // Where the deal had got to, counted again without them, so the next tile
    // laid down is the one that would have been.
    final before = _tiles.length;
    final pass = _next ~/ before;
    final at = _next % before;
    final kept = <int, int>{};
    for (var i = 0; i < before; i++) {
      if (!theirs(_tiles[i])) kept[i] = kept.length;
    }
    final waiting = [
      for (final i in _waiting)
        if (kept.containsKey(i)) kept[i]!,
    ];
    final keptBefore = kept.keys.where((i) => i < at).length;
    _tiles.removeWhere(theirs);
    _waiting
      ..clear()
      ..addAll(waiting);
    _next = pass * _tiles.length + keptBefore;

    if (_tiles.isEmpty) {
      _blocks.clear();
      return;
    }
    for (final block in _blocks.values) {
      for (var k = 0; k < block.length; k++) {
        if (theirs(block[k])) block[k] = _take(slots[k].$3);
      }
    }
  }

  /// The deal is running out: fewer than two blocks' worth left unseen.
  bool get runningLow => _tiles.length - math.min(_laid, _tiles.length) <
      slots.length * 2;

  /// The tiles of block ([bx], [by]), one per slot, in [slots] order.
  List<BlindTile> block(int bx, int by) {
    if (_tiles.isEmpty) return const [];
    return _blocks.putIfAbsent((bx, by), () {
      return [for (final (_, _, size) in slots) _take(size)];
    });
  }

  BlindTile _take(TileSize size) {
    _laid++;
    // Once everything has been laid down the deal starts again from the top:
    // a plane with no end repeats, and repeats far apart read as a plane.
    // A pass is finished before the next one starts: a tile not yet seen is
    // laid down ahead of a repeat, even where it does not fit the slot.
    while (_waiting.length < _lookahead &&
        (_next % _tiles.length != 0 || _next == 0 || _waiting.isEmpty)) {
      _waiting.add(_next % _tiles.length);
      _next++;
    }
    for (var i = 0; i < _waiting.length; i++) {
      if (fits(_tiles[_waiting[i]], size)) {
        return _tiles[_waiting.removeAt(i)];
      }
    }
    return _tiles[_waiting.removeAt(0)];
  }

  /// Whether a tile reads in a slot this size.
  ///
  /// A sentence (an answer) or a long value ("Prateek Kuhad") needs the width;
  /// a short number reads anywhere. A tall slot is one column wide, so it
  /// takes an answer, which wraps, but not a long value, which would shrink.
  static bool fits(BlindTile t, TileSize size) {
    final tile = t.tile;
    final long = !tile.isAnswer && tile.headline.length > 6;
    return switch (size) {
      TileSize.wide || TileSize.large => tile.isAnswer || long,
      TileSize.tall => tile.isAnswer || !long,
      TileSize.small => !tile.isAnswer && !long,
    };
  }
}
