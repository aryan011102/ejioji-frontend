import 'package:ejioji/core/network/json.dart';
import 'package:ejioji/shared/format.dart';
import 'package:ejioji/shared/models/enums.dart';
import 'package:ejioji/shared/models/person.dart';
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

  group('the filters added 2026-09-20', () {
    test('an empty filter parses as empty, not as null', () {
      // Empty means "narrows nothing" everywhere, and empty cities means your
      // own city. A null slipping through here would be a crash on a screen
      // that iterates them.
      final prefs = MatchPreferences.fromJson(const {
        'show_genders': ['woman'],
        'age_min': 24,
        'age_max': 32,
        'age_is_default': false,
      });
      expect(prefs.cities, isEmpty);
      expect(prefs.languages, isEmpty);
      expect(prefs.educationLevels, isEmpty);
    });

    test('a value the app has never heard of is dropped, not fatal', () {
      // Same rule as the enums above: the server can add a language without
      // waiting for a release, and the chip for it simply does not show.
      final prefs = MatchPreferences.fromJson(const {
        'show_genders': ['woman'],
        'age_is_default': true,
        'cities': ['mumbai', 'atlantis'],
        'languages': ['tamil', 'klingon'],
        'education_levels': ['masters', 'gcse'],
      });
      expect(prefs.cities, [City.mumbai]);
      expect(prefs.languages, [Language.tamil]);
      expect(prefs.educationLevels, [Education.masters]);
    });

    test('the wire format is sent for the new lists too', () {
      expect(Language.odia.wire, 'odia');
      expect(Education.bachelors.wire, 'bachelors');
      expect(Education.bachelors.label, "Bachelor's");
      expect(City.jaipur.wire, 'jaipur');
    });
  });

  group('a profile with an optional name and background', () {
    test('a missing last name is null and the name is just the first', () {
      final profile = Profile.fromJson({
        'first_name': 'Priya',
        'birth_date': '1998-04-12',
        'age': 27,
        'gender': 'woman',
        'city': 'bengaluru',
      });
      expect(profile.lastName, isNull);
      expect(profile.displayName, 'Priya');
      expect(profile.languages, isEmpty);
      expect(profile.education, isNull);
    });

    test('a last name joins the first with one space', () {
      final profile = Profile.fromJson({
        'first_name': 'Priya',
        'last_name': 'Nair',
        'birth_date': '1998-04-12',
        'age': 27,
        'gender': 'woman',
        'city': 'bengaluru',
        'languages': ['hindi', 'tamil'],
        'education': 'masters',
      });
      expect(profile.displayName, 'Priya Nair');
      expect(profile.languages, [Language.hindi, Language.tamil]);
      expect(profile.education, Education.masters);
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
  group('when a thin category is asked about', () {
    PromptBank bank({
      List<String> asked = const ['shopping', 'music'],
      int below = 2,
      List<String> questions = const ['shopping', 'shopping', 'music'],
    }) =>
        PromptBank.fromJson(<String, Object?>{
          'prompts': [
            for (var i = 0; i < questions.length; i++)
              {
                'key': 'q$i',
                'category': questions[i],
                'text': 'A question',
                'kind': 'text',
                'options': <Object>[],
                'max_chars': 80,
                'starter': i == 0,
              },
          ],
          'answers': <Object>[],
          'asked_categories': asked,
          'ask_below_tiles': below,
        });

    test('a category with one computed tile is still asked about', () {
      // One tile is a thin section of a profile. Nought and one both ask; two
      // stands on its own.
      expect(bank().asks(TileCategory.shopping, 0), isTrue);
      expect(bank().asks(TileCategory.shopping, 1), isTrue);
      expect(bank().asks(TileCategory.shopping, 2), isFalse);
      expect(bank().asks(TileCategory.shopping, 9), isFalse);
    });

    test('a category no source fills is never asked about', () {
      // Travel, going out and home have no source, so asking whenever they
      // came back empty would ask everyone, forever, on every setup.
      expect(bank().asks(TileCategory.travel, 0), isFalse);
      expect(bank().asks(TileCategory.watching, 0), isFalse);
    });

    test('a category with no questions left is not asked about', () {
      // Retiring a question is how copy changes. Retiring all of a category's
      // would otherwise draw a screen that asks nothing.
      final musicOnly = bank(questions: const ['music']);
      expect(musicOnly.asks(TileCategory.shopping, 0), isFalse);
    });

    test('the server decides the rule, not the app', () {
      // Both numbers come down the wire, so the rule can change without a
      // release.
      expect(bank(below: 3).asks(TileCategory.music, 2), isTrue);
      expect(bank(asked: const []).asks(TileCategory.music, 0), isFalse);
      // A category from a newer server is dropped rather than kept as
      // `unknown`, which would match every category this build cannot name.
      expect(bank(asked: const ['gaming']).askedCategories, isEmpty);
    });
  });

  group('pronouns', () {
    test('are null when the server says nothing, never guessed from gender', () {
      final profile = Profile.fromJson({
        'first_name': 'Priya',
        'birth_date': '1998-04-12',
        'age': 27,
        'gender': 'woman',
        'city': 'bengaluru',
      });
      // The whole reason the field exists is people whose pronouns do not follow
      // their gender. A default would mislabel them on every profile that never
      // opened the editor.
      expect(profile.pronouns, isNull);
    });

    test('are read from the closed list', () {
      final profile = Profile.fromJson({
        'first_name': 'Alex',
        'birth_date': '1998-04-12',
        'age': 27,
        'gender': 'non_binary',
        'city': 'bengaluru',
        'pronouns': 'they_them',
      });
      expect(profile.pronouns, Pronouns.theyThem);
      expect(profile.pronouns!.label, 'they/them');
    });

    test('a value this build has never heard of is not stated, not a crash', () {
      expect(Pronouns.parse('ze_zir'), isNull);
      expect(Pronouns.parse(''), isNull);
      expect(Pronouns.parse(null), isNull);
    });

    test('a card carries what the header shows, and never a surname', () {
      final card = Candidate.fromJson({
        'user_id': '11111111-1111-1111-1111-111111111111',
        'first_name': 'Ananya',
        'last_name': 'Garg',
        'age': 28,
        'city': 'bengaluru',
        'languages': ['hindi', 'english'],
        'education': 'bachelors',
        'pronouns': 'she_her',
      });
      expect(card.pronouns, Pronouns.sheHer);
      expect(card.languages, [Language.hindi, Language.english]);
      expect(card.education, Education.bachelors);
      // A surname beside purchase history is the caste inference, so a card has
      // no field for one however much the server sends.
      expect(card.firstName, 'Ananya');
    });
  });
}
