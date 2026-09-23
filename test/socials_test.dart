import 'package:ejioji/shared/models/person.dart';
import 'package:ejioji/shared/models/social.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _card() => {
      'user_id': 'u1',
      'first_name': 'Ananya',
      'age': 28,
      'city': 'bengaluru',
      'languages': <String>[],
      'education': null,
      'pronouns': null,
      'photos': <Object>[],
      'tiles': <Object>[],
    };

void main() {
  test("a match carries the other person's socials onto their card", () {
    final match = Match.fromJson({
      'id': 'm1',
      'matched_at': '2026-09-23T10:00:00Z',
      'person': _card(),
      'socials': [
        {
          'network': 'instagram',
          'display': '@ananya',
          'url': 'https://www.instagram.com/ananya/',
        },
        // A network this build does not know is dropped, not shown blank.
        {'network': 'threads', 'display': '@ananya', 'url': 'https://x'},
      ],
    });
    final link = match.person.socials.single;
    expect(link.network, SocialNetwork.instagram);
    expect(link.display, '@ananya');
    expect(link.shown, isTrue);
  });

  test('a feed card has no socials', () {
    expect(Candidate.fromJson(_card()).socials, isEmpty);
  });

  test('your own link keeps its handle and switch', () {
    final link = SocialLink.fromJson({
      'network': 'linkedin',
      'handle': 'ananya-garg',
      'display': 'ananya-garg',
      'url': 'https://www.linkedin.com/in/ananya-garg/',
      'shown': false,
    });
    expect(link.handle, 'ananya-garg');
    expect(link.shown, isFalse);
  });
}
