import 'package:ejioji/core/network/json.dart';
import 'package:ejioji/shared/format.dart';
import 'package:ejioji/shared/models/enums.dart';
import 'package:ejioji/shared/models/profile.dart';
import 'package:ejioji/shared/models/tile.dart';
import 'package:ejioji/shared/models/tile_look.dart';
import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the parts that can be wrong silently.
///
/// Widgets are not tested here: they need platform channels for the keychain
/// and the network, and a test that mocks all of that mostly tests the mocks.
/// What is worth pinning is the layer between the API and the screens, because
/// its failures are quiet ones. A misparsed enum does not throw, it renders the
/// wrong thing.
void main() {
  group('enums survive a server that moves ahead of the app', () {
    test('an unknown value falls back rather than throwing', () {
      // The backend can add a city, a report reason or a media kind without
      // waiting for an app release. A client that threw on one would break in
      // the field for everybody who had not updated.
      expect(City.parse('kochi'), City.unknown);
      expect(SourceProvider.parse('instagram'), SourceProvider.unknown);
      expect(TileCategory.parse('gaming'), TileCategory.unknown);
      expect(RunStatus.parse('paused'), RunStatus.unknown);
      expect(City.parse(null), City.unknown);
    });

    test('the wire format is sent, not the Dart name', () {
      // `nonBinary` and `non_binary` are not the same string, and sending the
      // Dart name would be refused by the server for every multi-word value.
      expect(Gender.nonBinary.wire, 'non_binary');
      expect(City.delhiNcr.wire, 'delhi_ncr');
      expect(ConsentPurpose.gmailReceipts.wire, 'gmail_receipts');
      expect(TileCategory.foodDelivery.wire, 'food_delivery');
    });

    test('every source names the consent purpose that gates it', () {
      // The server refuses to authorize a source whose purpose is not open, so
      // a wrong mapping here means a connect button that always fails.
      for (final provider in SourceProvider.values) {
        if (provider == SourceProvider.unknown) continue;
        expect(
          provider.purpose,
          isNot(ConsentPurpose.unknown),
          reason: '${provider.wire} has no consent purpose',
        );
      }
      expect(SourceProvider.gmail.purpose, ConsentPurpose.gmailReceipts);
      expect(SourceProvider.netflix.purpose, ConsentPurpose.netflixUpload);
    });
  });

  group('reading JSON', () {
    test('a missing field names itself rather than throwing a TypeError', () {
      final body = <String, Object?>{'key': 'abc'};
      expect(
        () => body.str('display_value'),
        throwsA(
          isA<MalformedResponse>()
              .having((e) => e.field, 'field', 'display_value'),
        ),
      );
    });

    test('timestamps come back in local time, dates do not move', () {
      final body = <String, Object?>{
        'sent_at': '2026-09-16T04:30:00Z',
        'birth_date': '1998-03-14',
      };
      expect(body.time('sent_at').isUtc, isFalse);
      // A birth date has no timezone. Parsing it as an instant and shifting it
      // would make somebody a day younger west of Greenwich.
      final born = body.date('birth_date');
      expect(born.year, 1998);
      expect(born.month, 3);
      expect(born.day, 14);
    });

    test('an absent list reads as empty, not null', () {
      expect(<String, Object?>{}.objects('tiles'), isEmpty);
      expect(<String, Object?>{}.strings('providers'), isEmpty);
    });
  });

  group('publish state', () {
    test('a profile is paused only when it could be showing', () {
      // Unpublished and able to publish is somebody taking a break.
      // Unpublished and below the bar is somebody who has not finished, and
      // the two need different copy.
      final paused = PublishState.fromJson(<String, Object?>{
        'published': false,
        'visible': false,
        'under_review': false,
        'blocking': <Object?>[],
      });
      expect(paused.canPublish, isTrue);

      final unfinished = PublishState.fromJson(<String, Object?>{
        'published': false,
        'visible': false,
        'under_review': false,
        'blocking': [
          {'code': 'too_few_photos', 'have': 1, 'need': 2},
        ],
      });
      expect(unfinished.canPublish, isFalse);
      expect(unfinished.blocking.single.message, contains('2'));
    });
  });

  group('how a tile looks', () {
    ProfileTile tileWith(String value, TileCategory category) =>
        ProfileTile.fromJson(<String, Object?>{
          'kind': 'insight',
          'key': 'k',
          'category': category.wire,
          'insight': {
            'key': 'k',
            'origin': 'template',
            'category': category.wire,
            'value': {'kind': 'count', 'number': 1},
            'display_value': value,
            'caption': 'c',
            'support': 10,
            'providers': <Object?>[],
            'computed_at': '2026-09-16T04:30:00Z',
          },
        });

    test('a long value gets a bigger box', () {
      // The number is the point of the tile. Shrinking "Prateek Kuhad" to fit
      // a square chosen before anyone looked at it is how a wall stops being
      // readable.
      expect(tileWith('62%', TileCategory.music).tileSize, TileSize.small);
      expect(tileWith('3:12 AM', TileCategory.music).tileSize, TileSize.wide);
      expect(
        tileWith('Prateek Kuhad', TileCategory.music).tileSize,
        TileSize.large,
      );
    });

    test('colour follows the category, not the position', () {
      // Two tiles in the same category look the same wherever they sit, so
      // adding one does not repaint the wall.
      expect(
        tileWith('1', TileCategory.music).tone,
        tileWith('999', TileCategory.music).tone,
      );
      expect(
        tileWith('1', TileCategory.music).tone,
        isNot(tileWith('1', TileCategory.travel).tone),
      );
    });
  });

  group('relative time', () {
    final now = DateTime(2026, 9, 16, 9);

    test('late last night reads as yesterday, not as hours', () {
      // Calendar days rather than 24-hour blocks. Something at 11pm is
      // "yesterday" the next morning, which is how a person reads a chat list.
      expect(
        relativeTime(DateTime(2026, 9, 15, 23), now: now),
        'Yesterday',
      );
      expect(relativeTime(DateTime(2026, 9, 16, 8), now: now), '1h');
      expect(relativeTime(DateTime(2026, 9, 16, 8, 58), now: now), '2m');
    });

    test('a clock skew into the future does not print a negative', () {
      expect(relativeTime(DateTime(2026, 9, 16, 10), now: now), 'now');
    });
  });
}
