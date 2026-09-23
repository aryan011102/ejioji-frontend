import 'package:ejioji/data/activity_repository.dart';
import 'package:ejioji/data/providers.dart';
import 'package:ejioji/features/home/presentation/notifications_page.dart';
import 'package:ejioji/shared/models/activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shapes copied from the backend's activity/schemas.py. Nothing else in the
/// app reads them, so a mistake here is a blank or wrong row on a real phone.
Map<String, Object?> row(String kind, {Map<String, Object?> extra = const {}}) =>
    {
      'kind': kind,
      'at': '2026-09-23T10:00:00+00:00',
      'new': true,
      'person': null,
      'request_id': null,
      'match_id': null,
      'message': null,
      'reason': null,
      'count': null,
      ...extra,
    };

const priya = {'user_id': 'u-1', 'first_name': 'Priya', 'photo': null};

ActivityItem parse(Map<String, Object?> json) => ActivityItem.fromJson(json);

class _FakeRepository implements ActivityRepository {
  _FakeRepository(this.page);

  final ActivityPage page;
  int seen = 0;

  @override
  Future<ActivityPage> load() async => page;

  @override
  Future<void> markSeen() async => seen++;
}

void main() {
  group('reading the page', () {
    test('a message carries who, which conversation and what it said', () {
      final item = parse(
        row(
          'message',
          extra: {
            'person': priya,
            'match_id': 'm-1',
            'message': {'kind': 'text', 'preview': 'Free on Sunday?'},
          },
        ),
      );
      expect(item.kind, ActivityKind.message);
      expect(item.person?.firstName, 'Priya');
      expect(item.matchId, 'm-1');
      expect(item.preview, 'Free on Sunday?');
      expect(item.isNew, isTrue);
    });

    test('a kind this build does not know is left off, not drawn wrong', () {
      final page = ActivityPage.fromJson({
        'items': [
          row('profile_view'),
          row('tiles_ready', extra: {'count': 3}),
        ],
        'new': 2,
      });
      expect(page.items.map((i) => i.kind), [ActivityKind.tilesReady]);
      expect(page.items.single.count, 3);
      expect(page.newCount, 2);
    });
  });

  group('what a row says', () {
    test('each kind in words', () {
      expect(
        activityCopy(parse(row('request', extra: {'person': priya}))).title,
        'Priya wants to chat',
      );
      expect(
        activityCopy(parse(row('match', extra: {'person': priya}))).title,
        'You and Priya matched',
      );
      final message = activityCopy(
        parse(
          row(
            'message',
            extra: {
              'person': priya,
              'message': {'kind': 'text', 'preview': 'hi'},
            },
          ),
        ),
      );
      expect(message.title, 'Priya sent you a message');
      expect(message.body, '“hi”');
      final photo = activityCopy(
        parse(
          row(
            'message',
            extra: {
              'person': priya,
              'message': {'kind': 'photo', 'preview': null},
            },
          ),
        ),
      );
      expect(photo.body, 'Sent a photo.');
      expect(
        activityCopy(parse(row('tiles_ready', extra: {'count': 1}))).title,
        '1 new tile to pick from',
      );
    });

    test('a takedown gives the reason, and a vague one for an unknown reason',
        () {
      expect(
        activityCopy(parse(row('taken_down', extra: {'reason': 'child'}))).body,
        'It showed a child, or someone who looks under 18.',
      );
      expect(
        activityCopy(parse(row('taken_down'))).body,
        'It broke the community rules.',
      );
    });
  });

  group('the page', () {
    Future<_FakeRepository> pump(WidgetTester tester, ActivityPage page) async {
      final fake = _FakeRepository(page);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [activityRepositoryProvider.overrideWithValue(fake)],
          child: const MaterialApp(home: NotificationsPage()),
        ),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('opening it marks everything seen, and keeps the dots',
        (tester) async {
      final fake = await pump(
        tester,
        ActivityPage(
          items: [parse(row('request', extra: {'person': priya}))],
          newCount: 1,
        ),
      );
      expect(find.text('Priya wants to chat'), findsOneWidget);
      expect(fake.seen, 1);
      // Still shown as new on this visit, so you can see what was.
      expect(find.byKey(const ValueKey('new-dot')), findsOneWidget);
    });

    testWidgets('nothing new is not marked again', (tester) async {
      final fake = await pump(
        tester,
        ActivityPage(
          items: [
            parse({
              ...row('match', extra: {'person': priya}),
              'new': false,
            }),
          ],
          newCount: 0,
        ),
      );
      expect(fake.seen, 0);
      expect(find.byKey(const ValueKey('new-dot')), findsNothing);
    });

    testWidgets('an empty page says what will show up', (tester) async {
      await pump(tester, const ActivityPage(items: [], newCount: 0));
      expect(find.text('Nothing yet'), findsOneWidget);
    });
  });
}
