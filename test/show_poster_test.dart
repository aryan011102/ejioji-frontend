import 'package:ejioji/shared/models/tile.dart';
import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _insight({Map<String, Object?>? poster}) => {
      'key': 'k1',
      'origin': 'template',
      'category': 'netflix',
      'value': {
        'kind': 'entity',
        'number': 185,
        'entity_label': 'The Office (U.S.)',
        'entity_ref': 'show:the office (u.s.)',
      },
      'display_value': 'The Office (U.S.)',
      'caption': 'The most-watched show.',
      'support': 185,
      'providers': ['netflix'],
      'computed_at': '2026-10-10T10:00:00Z',
      if (poster != null) 'poster': poster,
    };

const _poster = {
  'name': 'The Office',
  'year': 2005,
  'poster_url': 'https://image.tmdb.org/t/p/w500/office.jpg',
  'tmdb_url': 'https://www.themoviedb.org/tv/2316',
};

const _song = SongMusic(
  title: 'Kasoor',
  artist: 'Prateek Kuhad',
  artworkUrl: 'https://is1-ssl.mzstatic.com/x/600x600bb.jpg',
);

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 172, height: 260, child: child)),
    );

/// The URLs of every network image the tile draws.
List<String> _images(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((i) => i.image)
    .whereType<NetworkImage>()
    .map((i) => i.url)
    .toList();

void main() {
  group('a show on a tile', () {
    test('is read, and is absent on other tiles', () {
      final got = Insight.fromJson(_insight(poster: _poster)).poster!;
      expect(got.name, 'The Office');
      expect(got.year, 2005);
      expect(got.posterUrl, 'https://image.tmdb.org/t/p/w500/office.jpg');
      expect(Insight.fromJson(_insight()).poster, isNull);
    });

    test('a year TMDB does not have is no year', () {
      final got = Insight.fromJson(
        _insight(poster: {..._poster, 'year': null}),
      ).poster!;
      expect(got.year, isNull);
    });

    testWidgets('draws its poster behind the tile', (tester) async {
      final poster = Insight.fromJson(_insight(poster: _poster)).poster;
      await tester.pumpWidget(_wrap(InsightTile(
        size: TileSize.tall,
        number: 'The Office (U.S.)',
        poster: poster,
      ),),);
      expect(_images(tester), [_poster['poster_url']]);
    });

    testWidgets("the person's own photo wins over the poster", (tester) async {
      final poster = Insight.fromJson(_insight(poster: _poster)).poster;
      await tester.pumpWidget(_wrap(InsightTile(
        size: TileSize.tall,
        number: 'The Office (U.S.)',
        poster: poster,
        mediaUrl: 'https://example.blob.core.windows.net/media/mine.jpg',
      ),),);
      expect(
        _images(tester),
        ['https://example.blob.core.windows.net/media/mine.jpg'],
      );
    });

    testWidgets('a song cover wins over a poster', (tester) async {
      final poster = Insight.fromJson(_insight(poster: _poster)).poster;
      await tester.pumpWidget(_wrap(InsightTile(
        size: TileSize.tall,
        number: 'Kasoor',
        music: _song,
        poster: poster,
      ),),);
      expect(_images(tester), [_song.artworkUrl]);
    });
  });
}
