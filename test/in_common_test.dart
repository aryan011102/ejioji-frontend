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
        "You've both lost a whole day to Netflix.",
        category: 'netflix',
        chart: {
          'type': 'numbers',
          'me': side(22, '22', 'viewings in one day, you'),
          'them': side(14, '14', 'viewings in one day, Meera'),
        },
      ),
      story(
        'common',
        'Different kitchens. Same loyalty.',
        category: 'food_delivery',
        chart: {
          'type': 'names',
          'me': side(8, 'Bikkgane Biryani', 'you · 8 orders', 'food_delivery'),
          'them': side(9, 'Taco Bell', 'Meera · 9 orders', 'food_delivery'),
        },
      ),
      story(
        'common',
        'One artist, again and again.',
        category: 'music',
        chart: {
          'type': 'names',
          'me': side(6, 'Aditya Rikhari', 'you · Saved more than anyone else. 6 songs.'),
          'them': side(13, 'Faqeeran - Live', 'Meera · The most-played song. 13 times over.'),
        },
      ),
      story(
        'common',
        'You both keep the old ones close.',
        chart: {
          'type': 'records',
          'me': side(1971, '1971', 'you · The oldest song saved.'),
          'them': side(1975, '1975', 'Meera · The oldest video liked.', 'watching'),
        },
      ),
      {
        ...story('common', '2 of your top shows match.', category: 'netflix'),
        'chart': {
          'type': 'ranks',
          'me': side(9, 'Friends', 'you'),
          'them': side(8, 'Dark', 'Meera'),
          'me_ranks': [
            {'label': 'Friends', 'display': '9', 'shared': true},
            {'label': 'Dark', 'display': '5', 'shared': true},
            {'label': 'Lost', 'display': '3', 'shared': false},
          ],
          'them_ranks': [
            {'label': 'Dark', 'display': '8', 'shared': true},
            {'label': 'Friends', 'display': '6', 'shared': true},
          ],
        },
      },
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
    expect(deck.stories, hasLength(12));
    final ranks = deck.stories.firstWhere((s) => s.chart?.type == ChartType.ranks).chart!;
    expect(ranks.meRanks.map((r) => r.shared), [true, true, false]);
    expect(ranks.themRanks.first.label, 'Dark');
    expect(deck.stories.first.kind, StoryKind.intro);
    expect(deck.stories[1].chart!.type, ChartType.hours);
    expect(deck.stories[1].chart!.them.label, 'Meera');
    expect(deck.stories[1].onProfileThem, isFalse);
    expect(deck.stories.last.chart!.type, ChartType.versus);
    final types = deck.stories.map((s) => s.chart?.type).toSet();
    expect(types, containsAll([ChartType.names, ChartType.records]));
  });

  testWidgets('two songs or artists are records; two kitchens are cards', (tester) async {
    final deck = InCommon.fromJson(body);
    StoryChart named(String title) => deck.stories.firstWhere((s) => s.title == title).chart!;
    final spinning = find.descendant(
      of: find.byType(StoryChartView),
      matching: find.byType(RotationTransition),
    );
    Future<void> draw(StoryChart chart) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 327, child: StoryChartView(chart: chart, name: 'Meera')),
            ),
          ),
        );

    await draw(named('One artist, again and again.'));
    await tester.pump(const Duration(seconds: 1));
    expect(spinning, findsNWidgets(2));
    expect(find.text('Aditya Rikhari'), findsOneWidget);
    expect(find.text('Faqeeran - Live'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await draw(named('Different kitchens. Same loyalty.'));
    await tester.pump(const Duration(seconds: 1));
    expect(spinning, findsNothing);
    expect(find.text('Bikkgane Biryani'), findsOneWidget);
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

  testWidgets('no story says where its tiles live', (tester) async {
    final deck = InCommon.fromJson(body);
    await tester.pumpWidget(MaterialApp(home: StoryViewer(deck: deck)));
    await tester.tapAt(const Offset(300, 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('INSIGHTS'), findsNothing);
    expect(find.textContaining('PROFILE'), findsNothing);
  });

  testWidgets('both photos on the intro sit whole inside their box', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final deck = InCommon.fromJson(body);
    await tester.pumpWidget(MaterialApp(home: StoryViewer(deck: deck)));
    await tester.pump(const Duration(seconds: 1));
    final faces = find.byKey(StoryViewer.faceKey);
    // The intro's two, the biggest on screen.
    final rects = [for (var i = 0; i < faces.evaluate().length; i++) tester.getRect(faces.at(i))]
      ..sort((a, b) => b.width.compareTo(a.width));
    final big = rects.take(2).toList();
    expect(big, hasLength(2));
    final box = tester.getRect(
      find.ancestor(of: faces.first, matching: find.byType(SizedBox)).first,
    );
    for (final r in rects.where((r) => r.width == big.first.width)) {
      expect(box.inflate(0.01).contains(r.topLeft), isTrue, reason: '$r in $box');
      expect(box.inflate(0.01).contains(r.bottomRight), isTrue, reason: '$r in $box');
    }
    for (final c in tester.widgetList<Container>(faces)) {
      final border = (c.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, const Color(0xFF000000));
    }
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

  testWidgets('every story but the intro can be replied to', (tester) async {
    final replies = <String>[];
    final deck = InCommon.fromJson(body);
    await tester.pumpWidget(
      MaterialApp(
        home: StoryViewer(
          deck: deck,
          onReply: (story, text) async {
            replies.add('${story.title}|$text');
            return null;
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Chat about this'), findsNothing);
    await tester.tapAt(const Offset(300, 400));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Chat about this'));
    await tester.pumpAndSettle();
    expect(find.text('Send to Meera'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'same, 2pm is sacred');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(replies, ['2 PM. For both of you.|same, 2pm is sacred']);
  });
}
