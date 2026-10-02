import 'package:ejioji/features/profile/presentation/arrange_wall.dart';
import 'package:ejioji/shared/models/tile.dart';
import 'package:ejioji/shared/models/tile_look.dart';
import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Values of different lengths, so the wall mixes small, wide and large tiles
/// and the packing depends on what comes first.
ProfileTile _tile(String key, String value) => ProfileTile.fromJson({
      'kind': 'insight',
      'key': key,
      'category': 'food_delivery',
      'insight': {
        'key': key,
        'origin': 'floor',
        'category': 'food_delivery',
        'value': {'kind': 'count', 'number': 1},
        'display_value': value,
        'caption': 'A caption',
        'support': 10,
        'providers': <String>[],
        'computed_at': '2026-09-30T10:00:00+00:00',
      },
    });

final _tiles = [
  _tile('a', '142'),
  _tile('b', '11:40 PM'),
  _tile('c', 'Prateek Kuhad and friends'),
  _tile('d', '62%'),
  _tile('e', 'Tuesday'),
  _tile('f', '9'),
  _tile('g', '3'),
];

const _photos = BentoItem(
  size: TileSize.small,
  child: ColoredBox(key: Key('photos'), color: Colors.grey),
);

Future<List<Rect>> _rects(WidgetTester tester, Widget wall) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: wall))),
  );
  await tester.pump();
  return [
    tester.getRect(find.byKey(const Key('photos'))),
    for (final e in find.byType(InsightTile).evaluate())
      tester.getRect(find.byWidget(e.widget)),
  ];
}

void main() {
  testWidgets('arrange mode keeps the photos tile and every tile where the '
      'wall has it', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final wall = await _rects(
      tester,
      BentoGrid(
        children: [
          _photos,
          for (final t in _tiles)
            BentoItem(
              size: t.tileSize,
              child: InsightTile(
                size: t.tileSize,
                number: t.headline,
                caption: t.body,
                tone: t.tone,
              ),
            ),
        ],
      ),
    );

    final arranging = await _rects(
      tester,
      ArrangeWall(
        photos: _photos,
        tiles: _tiles,
        mediaOf: (_) => null,
        mediaBusy: (_) => false,
        onMedia: (_) {},
        onReorder: (_, __) {},
        onRemove: (_) {},
        onFloorHit: () {},
      ),
    );

    expect(arranging.length, wall.length);
    for (var i = 0; i < wall.length; i++) {
      // The wobble tilts a tile by well under a degree, which moves its
      // bounding box a pixel or two. A tile in the wrong place is a whole
      // cell away.
      expect(
        (arranging[i].center - wall[i].center).distance,
        lessThan(4),
        reason: 'tile $i moved from ${wall[i]} to ${arranging[i]}',
      );
    }
  });
}
