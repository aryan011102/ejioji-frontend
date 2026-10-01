import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every cell of every row is covered exactly once, and no tile is bigger
/// than two by two.
void _gapless(List<TileSize> sizes) {
  final slots = StaggeredGrid.pack(sizes);
  expect(slots.length, sizes.length);
  final cells = <(int, int)>{};
  var rows = 0;
  for (final s in slots) {
    expect(s.w, inInclusiveRange(1, 2));
    expect(s.h, inInclusiveRange(1, 2));
    expect(s.col + s.w, lessThanOrEqualTo(2));
    for (var r = s.row; r < s.bottom; r++) {
      for (var c = s.col; c < s.col + s.w; c++) {
        expect(cells.add((r, c)), isTrue, reason: 'overlap in $sizes: $slots');
      }
    }
    if (s.bottom > rows) rows = s.bottom;
  }
  expect(cells.length, rows * 2, reason: 'a gap in $sizes: $slots');
}

void main() {
  test('a lone small tile in a row is made wide', () {
    expect(
      StaggeredGrid.pack([TileSize.wide, TileSize.small]),
      const [Slot(row: 0, col: 0, w: 2, h: 1), Slot(row: 1, col: 0, w: 2, h: 1)],
    );
  });

  test('a small tile beside a tall one grows down to match it', () {
    expect(
      StaggeredGrid.pack([TileSize.tall, TileSize.small]),
      const [Slot(row: 0, col: 0, w: 1, h: 2), Slot(row: 0, col: 1, w: 1, h: 2)],
    );
  });

  test('a wall that already fits is left as it is', () {
    expect(
      StaggeredGrid.pack([TileSize.small, TileSize.small, TileSize.large]),
      const [
        Slot(row: 0, col: 0, w: 1, h: 1),
        Slot(row: 0, col: 1, w: 1, h: 1),
        Slot(row: 1, col: 0, w: 2, h: 2),
      ],
    );
  });

  test('every order of up to seven tiles leaves no gap', () {
    const all = TileSize.values;
    void walk(List<TileSize> sizes) {
      if (sizes.isNotEmpty) _gapless(sizes);
      if (sizes.length == 7) return;
      for (final s in all) {
        walk([...sizes, s]);
      }
    }

    walk([]);
  });
}
