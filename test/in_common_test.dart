import 'package:ejioji/data/in_common_repository.dart';
import 'package:ejioji/features/chats/presentation/in_common/in_common_ask.dart';
import 'package:ejioji/features/chats/presentation/in_common/story_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The in common stories (Aryan, 2026-10-10): what the server sends, read
/// whole, and every chart drawn on a phone without overflowing.
void main() {
  Map<String, Object?> side(double value, String display, String label, [String c = 'music']) =>
      {'value': value, 'display': display, 'label': label, 'category': c};

  Map<String, Object?> story(
    String kind,
    String title, {
    String? category,
    Map<String, Object?>? chart,
    bool? me,
    bool? them,
  }) =>
      {
        'kind': kind,
        'category': category,
        'eyebrow': 'Eyebrow',
        'title': title,
        'footnote': 'A footnote.',
        'chart': chart,
        'on_profile_me': me,
        'on_profile_them': them,
      };

  final body = <String, Object?>{
    'state': 'ready',
    'them_said_yes': true,
    'me': {'first_name': 'Arjun', 'photo': null},
    'them': {'first_name': 'Meera', 'photo': null},
    'stories': [
      story('intro', 'You & Meera, 5 things.'),
      story(
        'common',
        '2 PM. For both of you.',
        category: 'food_delivery',
        chart: {'type': 'hours', 'me': side(14, '2 PM', 'you'), 'them': side(14, '2 PM', 'Meera')},
        me: true,
        them: false,
      ),
      story(
        'common',
        'Fridays. Both of you.',
        category: 'music',
        chart: {
          'type': 'weekdays',
          'me': side(4, 'Friday', 'you'),
          'them': side(4, 'Friday', 'Meera'),
        },
        me: false,
        them: false,
      ),
      story(
        'common',
        'Friends. Both of you.',
        category: 'netflix',
        chart: {
          'type': 'bars',
          'me': side(154, '154', 'you · viewings'),
          'them': side(206, '206', 'Meera · viewings'),
        },
        me: true,
        them: true,
      ),
      story(
        'common',
        'December. For both of you.',
        category: 'shopping',
        chart: {
          'type': 'months',
          'me': side(12, 'December', 'you'),
          'them': side(12, 'December', 'Meera'),
        },
      ),
      story(
        'common',
        '1,000 and 1,100. Neck and neck.',
        category: 'music',
        chart: {
          'type': 'numbers',
          'me': side(1000, '1,000', 'you'),
          'them': side(1100, '1,100', 'Meera'),
        },
      ),
      story('thought', 'You bought a projector. Meera keeps going back to Friends.'),
      story(
        'differ',
        'You travel. Meera goes out.',
        chart: {
          'type': 'versus',
          'me': side(11, '11', 'you · flights booked', 'travel'),
          'them': side(55, '55', 'Meera · evenings out', 'going_out'),
        },
      ),
    ],
  };

  test('reads every story, chart and side', () {
    final deck = InCommon.fromJson(body);
    expect(deck.state, InCommonState.ready);
    expect(deck.canOpen, isTrue);
    expect(deck.stories, hasLength(8));
    expect(deck.stories.first.kind, StoryKind.intro);
    expect(deck.stories[1].chart!.type, ChartType.hours);
    expect(deck.stories[1].chart!.them.label, 'Meera');
    expect(deck.stories[1].onProfileThem, isFalse);
    expect(deck.stories.last.chart!.type, ChartType.versus);
  });

  test('not enough in common has no ring; waiting has one and does not open', () {
    final none = InCommon.fromJson({...body, 'state': 'not_enough', 'stories': <Object>[]});
    expect(none.hasRing, isFalse);
    final waiting = InCommon.fromJson({...body, 'state': 'waiting', 'stories': <Object>[]});
    expect(waiting.hasRing, isTrue);
    expect(waiting.canOpen, isFalse);
  });

  testWidgets('every story draws on a small phone, tapping through to the end', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final deck = InCommon.fromJson(body);
    await tester.pumpWidget(MaterialApp(home: StoryViewer(deck: deck)));
    for (final s in deck.stories) {
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(s.title), findsOneWidget);
      expect(tester.takeException(), isNull);
      // A quick tap on the right goes on.
      await tester.tapAt(const Offset(300, 400));
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  testWidgets('a story says where each tile lives', (tester) async {
    final deck = InCommon.fromJson(body);
    await tester.pumpWidget(MaterialApp(home: StoryViewer(deck: deck)));
    await tester.tapAt(const Offset(300, 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("ON YOUR PROFILE · IN MEERA'S INSIGHTS"), findsOneWidget);
  });

  testWidgets('the question names them, and no is as easy as yes', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InCommonAskCard(
              name: 'Meera',
              themSaidYes: true,
              onAllow: () => taps.add('allow'),
              onNotNow: () => taps.add('not now'),
              onReadNotice: () => taps.add('notice'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Meera wants to see what you two have in common'), findsOneWidget);
    expect(find.textContaining('kept off your profile'), findsOneWidget);
    await tester.tap(find.text('Show me'));
    await tester.tap(find.text('Not now'));
    await tester.tap(find.text('Read the full notice'));
    expect(taps, ['allow', 'not now', 'notice']);
  });
}
