import 'package:ejioji/shared/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> card(String id, String name) => {
        'user_id': id,
        'first_name': name,
        'age': 27,
        'city': 'bengaluru',
        'languages': <String>[],
        'education': null,
        'pronouns': null,
        'photos': <Object>[],
        'tiles': <Object>[],
      };

  test('views read the total and each visitor in the order sent', () {
    final views = ProfileViews.fromJson({
      'total': 140,
      'visitors': [
        {
          'last_viewed_at': '2026-09-26T10:00:00Z',
          'visits': 3,
          'person': card('u-2', 'Meera'),
        },
        {
          'last_viewed_at': '2026-09-20T18:30:00Z',
          'visits': 1,
          'person': card('u-1', 'Priya'),
        },
      ],
    });
    // The total counts everyone; the list is only the most recent hundred.
    expect(views.total, 140);
    expect([for (final v in views.visitors) v.person.firstName], [
      'Meera',
      'Priya',
    ]);
    expect(views.visitors.first.visits, 3);
    expect(
      views.visitors.first.lastViewedAt
          .isAtSameMomentAs(DateTime.utc(2026, 9, 26, 10)),
      isTrue,
    );
  });

  test('nobody yet is an empty list, not an error', () {
    final views = ProfileViews.fromJson({'total': 0, 'visitors': <Object>[]});
    expect(views.total, 0);
    expect(views.visitors, isEmpty);
  });
}
