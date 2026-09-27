import 'package:ejioji/shared/models/tile.dart';
import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _insight({Map<String, Object?>? music}) => {
      'key': 'k1',
      'origin': 'template',
      'category': 'music',
      'value': {
        'kind': 'entity',
        'number': 13,
        'entity_label': 'Kasoor',
        'entity_ref': 'track:prateek kuhad\tkasoor',
      },
      'display_value': 'Kasoor',
      'caption': 'The most-played song. 13 times over.',
      'support': 55,
      'providers': ['spotify'],
      'computed_at': '2026-09-27T10:00:00Z',
      if (music != null) 'music': music,
    };

const _song = {
  'title': 'Kasoor',
  'artist': 'Prateek Kuhad',
  'artwork_url': 'https://is1-ssl.mzstatic.com/x/600x600bb.jpg',
  'artwork_background': '1a2b3c',
  'preview_url': 'https://audio-ssl.itunes.apple.com/x.m4a',
  'apple_music_url': 'https://music.apple.com/in/album/kasoor/1?i=2',
  'spotify_url': null,
};

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, height: 172, child: child)),
    );

void main() {
  group('a song on a tile', () {
    test('is read with its cover colour, and is absent on other tiles', () {
      final got = Insight.fromJson(_insight(music: _song)).music!;
      expect(got.title, 'Kasoor');
      expect(got.artworkBackground, const Color(0xFF1A2B3C));
      expect(got.previewUrl, 'https://audio-ssl.itunes.apple.com/x.m4a');
      expect(got.spotifyUrl, isNull);
      expect(Insight.fromJson(_insight()).music, isNull);
    });

    test('a malformed colour is no colour, not a crash', () {
      final got = Insight.fromJson(
        _insight(music: {..._song, 'artwork_background': 'nothex'}),
      ).music!;
      expect(got.artworkBackground, isNull);
    });

    testWidgets('gets a play button and the Apple Music badge', (tester) async {
      final music = Insight.fromJson(_insight(music: _song)).music;
      await tester.pumpWidget(_wrap(InsightTile(
        size: TileSize.wide,
        number: 'Kasoor',
        caption: 'The most-played song.',
        isTrack: true,
        music: music,
      ),),);
      expect(find.byType(SongPreview), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets('has no player where a preview would be in the way',
        (tester) async {
      final music = Insight.fromJson(_insight(music: _song)).music;
      await tester.pumpWidget(_wrap(InsightTile(
        size: TileSize.wide,
        number: 'Kasoor',
        isTrack: true,
        music: music,
        playMusic: false,
      ),),);
      expect(find.byType(SongPreview), findsNothing);
    });

    testWidgets('without a song from the catalog, keeps the plain track look',
        (tester) async {
      await tester.pumpWidget(_wrap(const InsightTile(
        size: TileSize.wide,
        number: 'Kasoor',
        isTrack: true,
      ),),);
      expect(find.byType(SongPreview), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });
}
