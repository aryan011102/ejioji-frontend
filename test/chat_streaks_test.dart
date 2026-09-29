import 'package:ejioji/features/chats/presentation/streak_popup.dart';
import 'package:ejioji/shared/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chat streaks: days in a row both people wrote. The server sends one only
/// while it runs, with the milestone popup's line when one has been reached.
void main() {
  Map<String, Object?> page({Object? streak}) => {
        'messages': <Object?>[],
        'openers': <Object?>[],
        'has_more': false,
        'my_read_seq': 0,
        'their_read_seq': 0,
        if (streak != null) 'streak': streak,
      };

  test('a running streak with a milestone reads in full', () {
    final s = MessagePage.fromJson(
      page(
        streak: {
          'days': 4,
          'started_on': '2026-09-26',
          'milestone': {'days': 3, 'line': 'Careful, this is how it starts.'},
        },
      ),
    ).streak!;
    expect(s.days, 4);
    expect(s.milestone, 3);
    expect(s.line, 'Careful, this is how it starts.');
    expect(streakLabel(s), '🔥 4 days in a row');
  });

  test('no streak, or an older server, is nothing to show', () {
    expect(MessagePage.fromJson(page()).streak, isNull);
    expect(MessagePage.fromJson({...page(), 'streak': null}).streak, isNull);
  });

  test('a streak below its first milestone has no popup', () {
    final s = MessagePage.fromJson(
      page(streak: {'days': 2, 'started_on': '2026-09-28', 'milestone': null}),
    ).streak!;
    expect(s.popupKey('m1'), isNull);
  });

  test('a new streak reaching the same milestone pops up again', () {
    const first = Streak(days: 3, startedOn: '2026-09-01', milestone: 3, line: 'x');
    const again = Streak(days: 3, startedOn: '2026-09-20', milestone: 3, line: 'x');
    const later = Streak(days: 4, startedOn: '2026-09-01', milestone: 3, line: 'x');
    expect(first.popupKey('m1'), isNot(again.popupKey('m1')));
    // The same streak a day later is the same popup: it is not shown twice.
    expect(first.popupKey('m1'), later.popupKey('m1'));
    expect(first.popupKey('m1'), isNot(first.popupKey('m2')));
  });

  testWidgets('the popup says the milestone, the name and the line', (t) async {
    var done = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakCard(
            days: 5,
            line: 'Your phones have started expecting each other.',
            name: 'Priya',
            onDone: () => done = true,
          ),
        ),
      ),
    );
    expect(find.text('5'), findsOneWidget);
    expect(find.text('days in a row with Priya'), findsOneWidget);
    expect(find.text('Your phones have started expecting each other.'), findsOneWidget);
    await t.tap(find.text('Keep it going'));
    expect(done, isTrue);
  });
}
