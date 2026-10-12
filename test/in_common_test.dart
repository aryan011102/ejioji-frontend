import 'package:ejioji/data/in_common_repository.dart';
import 'package:ejioji/features/chats/presentation/in_common/in_common_ask.dart';
import 'package:ejioji/features/chats/presentation/in_common/story_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The in common stories (Aryan, 2026-10-10): what the server sends, read
/// whole, and every chart drawn on a phone without overflowing.
void main() {
  Map<String, Object?> side(double value, String display, String label, [String c = 'music']) =>
      {'value': value, 'display': display, 'label': label, 'category': c};

  List<int> day(int peak) => [for (var h = 0; h < 24; h++) h == peak ? 30 : (h + peak) % 5];

  Map<String, Object?> year(List<int> weeks) => {
        'weeks': weeks,
        'months': [for (var m = 0; m < 12; m++) weeks.skip(m * 4).take(4).fold<int>(0, (a, b) => a + b)],
        'first_month': 11,
        'first_year': 2025,
      };

  // A table nearly every week, and a handful of trips.
  final often = year([for (var w = 0; w < 52; w++) w % 7 == 3 ? 0 : 1]);
  final rarely = year([for (var w = 0; w < 52; w++) w == 4 || w == 30 || w == 31 ? 1 : 0]);

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
        chart: {
          'type': 'hours',
          'me': {...side(14, '2 PM', 'you'), 'series': day(14)},
          'them': {...side(14, '2 PM', 'Meera'), 'series': day(13)},
        },
        me: true,
        them: false,
      ),
      story(
        'common',
        'Fridays. Both of you.',
        category: 'music',
        chart: {
          'type': 'weekdays',
          'me': {...side(4, 'Friday', 'you · plays on a Friday'), 'series': [3, 4, 3, 5, 12, 6, 4]},
          'them': {...side(4, 'Friday', 'Meera · plays on a Friday'), 'series': [2, 2, 3, 4, 9, 5, 3]},
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
        'A trip a season, each of you.',
        category: 'travel',
        chart: {
          'type': 'year',
          'me': {...side(3, '3', 'you · trips booked', 'travel'), 'calendar': rarely},
          'them': {...side(3, '3', 'Meera · trips booked', 'travel'), 'calendar': rarely},
        },
      ),
      story(
        'common',
        'Both of you found Kurzgesagt before anyone here did.',
        category: 'watching',
        chart: {
          'type': 'words',
          'me': side(1, 'Kurzgesagt', 'you', 'watching'),
          'them': side(1, 'Kurzgesagt', 'Meera', 'watching'),
        },
      ),
      story(
        'common',
        'One artist, again and again.',
        category: 'music',
        chart: {
          'type': 'records',
          'me': side(6, 'Aditya Rikhari', 'you · Saved more than anyone else. 6 songs.'),
          'them': side(13, 'Faqeeran - Live', 'Meera · The most-played song. 13 times over.'),
        },
      ),
      story(
        'common',
        'You both keep the old ones close.',
        chart: {
          'type': 'records',
          'me': {
            ...side(1971, '1971', 'you · The year the oldest song saved came out. It is Kahin Door Jab Din Dhal Jaye.'),
            'name': 'Kahin Door Jab Din Dhal Jaye',
          },
          'them': {
            ...side(1949, '1949', 'Meera · The year the oldest song played came out. It is Lag Ja Gale Se Phir.'),
            'name': 'Lag Ja Gale Se Phir',
          },
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
      story(
        'common',
        'Weekends are when it happens. For both of you.',
        chart: {
          'type': 'numbers',
          'me': {...side(0.52, '52%', 'you · on a weekend', 'social'), 'series': [3, 3, 4, 3, 5, 9, 10]},
          'them': {
            ...side(0.48, '48%', 'Meera · on a weekend', 'social'),
            'series': [2, 4, 3, 3, 6, 8, 9],
          },
        },
      ),
      {
        ...story('common', 'Arijit Singh. Number one for both of you.', category: 'music'),
        'chart': {
          'type': 'ranks',
          'me': side(40, 'Arijit Singh', 'you'),
          'them': side(31, 'Arijit Singh', 'Meera'),
          'me_ranks': [
            {'label': 'Arijit Singh', 'display': '40', 'shared': true},
            {'label': 'Prateek Kuhad', 'display': '12', 'shared': false},
          ],
          'them_ranks': [
            {'label': 'Arijit Singh', 'display': '31', 'shared': true},
            {'label': 'Anuv Jain', 'display': '9', 'shared': false},
          ],
        },
      },
      {
        ...story('thought', 'You bought a projector. Meera keeps going back to Friends.'),
        'footnote': 'Ask Meera which season to skip first. Loser picks dinner.',
      },
      story(
        'differ',
        'You travel. Meera goes out.',
        chart: {
          'type': 'year',
          'me': {...side(11, '11', 'you · flights booked', 'travel'), 'calendar': rarely},
          'them': {...side(55, '55', 'Meera · evenings out', 'going_out'), 'calendar': often},
        },
      ),
    ],
  };

  test('reads every story, chart and side', () {
    final deck = InCommon.fromJson(body);
    expect(deck.state, InCommonState.ready);
    expect(deck.canOpen, isTrue);
    expect(deck.stories, hasLength(16));
    expect(deck.stories[1].chart!.me.series, hasLength(24));
    final differ = deck.stories.last.chart!;
    expect(differ.me.calendar!.weeks, hasLength(52));
    expect(differ.them.calendar!.total, greaterThan(StoryCalendarView.dotsUpTo));
    final ranks = deck.stories.firstWhere((s) => s.chart?.type == ChartType.ranks).chart!;
    expect(ranks.meRanks.map((r) => r.shared), [true, true, false]);
    expect(ranks.themRanks.first.label, 'Dark');
    expect(deck.stories.first.kind, StoryKind.intro);
    expect(deck.stories[1].chart!.type, ChartType.hours);
    expect(deck.stories[1].chart!.them.label, 'Meera');
    expect(deck.stories[1].onProfileThem, isFalse);
    expect(deck.stories.last.chart!.type, ChartType.year);
    final types = deck.stories.map((s) => s.chart?.type).toSet();
    expect(types, containsAll([ChartType.names, ChartType.records, ChartType.words]));
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

  testWidgets('a ranking is the two lists, nothing piled on top', (tester) async {
    final deck = InCommon.fromJson(body);
    StoryChart named(String title) => deck.stories.firstWhere((s) => s.title == title).chart!;
    final spinning = find.descendant(
      of: find.byType(StoryChartView),
      matching: find.byType(RotationTransition),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 327,
            child: StoryChartView(
              chart: named('Arijit Singh. Number one for both of you.'),
              name: 'Meera',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(spinning, findsNothing);
    expect(find.text('Prateek Kuhad'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a year of how often: weeks when there are many, dots when few', (tester) async {
    final deck = InCommon.fromJson(body);
    StoryChart named(String title) => deck.stories.firstWhere((s) => s.title == title).chart!;
    Future<void> draw(StoryChart chart) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 327, child: StoryChartView(chart: chart, name: 'Meera')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    }

    await draw(named('You travel. Meera goes out.'));
    expect(find.byType(StoryCalendarView), findsOneWidget);
    expect(find.text('J'), findsNothing, reason: 'a busy year is weeks, not month dots');
    expect(tester.takeException(), isNull);

    await draw(named('A trip a season, each of you.'));
    expect(find.byType(StoryCalendarView), findsOneWidget);
    expect(find.text('N'), findsWidgets, reason: 'a few things get a dot each, by month');
    expect(tester.takeException(), isNull);

    // A calendar is its own picture, never stacked under another one.
    await draw(named('Different kitchens. Same loyalty.'));
    expect(find.byType(StoryCalendarView), findsNothing);
  });

  testWidgets('no picture is shrunk to fit a phone', (tester) async {
    // The founder, 2026-10-11: the words on some stories were too small. The
    // picture was being scaled down to make room; every picture now fits.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final deck = InCommon.fromJson(body);
    await tester.pumpWidget(MaterialApp(home: StoryViewer(deck: deck)));
    for (final s in deck.stories) {
      await tester.pump(const Duration(seconds: 2));
      final fitted = find.byKey(StoryViewer.pictureKey);
      if (fitted.evaluate().isNotEmpty) {
        final box = tester.renderObject<RenderProxyBox>(fitted);
        expect(
          box.child!.size.height,
          lessThanOrEqualTo(box.size.height + 0.5),
          reason: '"${s.title}" was shrunk to fit',
        );
      }
      await tester.tapAt(const Offset(300, 400));
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  testWidgets('a story with no picture is its words alone', (tester) async {
    final deck = InCommon.fromJson(body);
    final at = deck.stories.indexWhere((s) => s.chart?.type == ChartType.words);
    await tester.pumpWidget(MaterialApp(home: StoryViewer(deck: deck)));
    for (var i = 0; i < at; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(const Offset(300, 400));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(deck.stories[at].title), findsOneWidget);
    expect(find.byType(StoryChartView), findsNothing);
    expect(find.text('Kurzgesagt'), findsNothing, reason: 'the words carry it');
  });

  testWidgets('the old songs are two overlapping records, each song named in full',
      (tester) async {
    final deck = InCommon.fromJson(body);
    final chart =
        deck.stories.firstWhere((s) => s.title == 'You both keep the old ones close.').chart!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 342, child: StoryChartView(chart: chart, name: 'Meera')),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1971'), findsOneWidget);
    expect(find.text('Kahin Door Jab Din Dhal Jaye'), findsOneWidget);
    expect(find.text('Lag Ja Gale Se Phir'), findsOneWidget);
    // Never cut: a name wraps rather than ending in an ellipsis.
    for (final key in ['in-common-record-name', 'in-common-record-label']) {
      final texts = tester.widgetList<Text>(find.byKey(ValueKey(key)));
      expect(texts, hasLength(2), reason: key);
      for (final text in texts) {
        expect(text.maxLines, isNull, reason: key);
        expect(text.overflow, isNot(TextOverflow.ellipsis), reason: key);
      }
    }
    // The whole caption is there, song and all.
    expect(
      find.text('The year the oldest song played came out. It is Lag Ja Gale Se Phir.'),
      findsOneWidget,
    );
    // The second record sits over the first.
    final discs = find.descendant(
      of: find.byType(StoryChartView),
      matching: find.byType(RotationTransition),
    );
    final first = tester.getRect(discs.at(0));
    final second = tester.getRect(discs.at(1));
    expect(second.left, lessThan(first.right - 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the thought carries a nudge, as plain sub copy', (tester) async {
    final deck = InCommon.fromJson(body);
    final at = deck.stories.indexWhere((s) => s.kind == StoryKind.thought);
    await tester.pumpWidget(MaterialApp(home: StoryViewer(deck: deck)));
    for (var i = 0; i < at; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(const Offset(300, 400));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 2));
    final nudge = find.text('Ask Meera which season to skip first. Loser picks dinner.');
    expect(nudge, findsOneWidget);
    // No box around it: nothing decorated sits between it and the slide.
    expect(
      find.ancestor(of: nudge, matching: find.byWidgetPredicate((w) => w is Container && w.decoration != null)),
      findsNothing,
    );
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
    expect(find.textContaining('kept off your profile'), findsNothing);
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
