import 'package:ejioji/shared/models/chat.dart';
import 'package:ejioji/shared/models/enums.dart';
import 'package:ejioji/shared/models/person.dart';
import 'package:ejioji/shared/models/tile.dart';
import 'package:ejioji/shared/widgets/quoted_tile.dart';
import 'package:ejioji/shared/widgets/swipe_to_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _insightQuote({bool removed = false}) => {
      'id': 'q1',
      'owner_id': 'her',
      'kind': 'insight',
      'category': 'food_delivery',
      'quoted_at': '2026-09-27T10:00:00+00:00',
      'removed': removed,
      'insight': removed
          ? null
          : {
              'value_kind': 'count',
              'display_value': '142',
              'caption': 'Orders this year',
            },
      'prompt': null,
    };

Map<String, Object?> _answerQuote() => {
      'id': 'q2',
      'owner_id': 'me',
      'kind': 'prompt',
      'category': 'music',
      'quoted_at': '2026-09-27T10:00:00+00:00',
      'removed': false,
      'insight': null,
      'prompt': {'question': 'The song on repeat', 'answer': 'Old Arijit'},
    };

Map<String, Object?> _message({Map<String, Object?>? tile}) => {
      'id': 'm1',
      'match_id': 'x',
      'seq': 1,
      'sender_id': 'me',
      'client_id': 'c1',
      'kind': 'text',
      'text': 'Twice?',
      'media': null,
      'tile': tile,
      'sent_at': '2026-09-27T10:00:00+00:00',
    };

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 300, height: 160, child: child)),
      ),
    );

void main() {
  group('a quoted tile', () {
    test('an insight reads its value and caption', () {
      final q = TileQuote.fromJson(_insightQuote());
      expect(q.kind, TileKind.insight);
      expect(q.category, TileCategory.foodDelivery);
      expect(q.displayValue, '142');
      expect(q.caption, 'Orders this year');
      expect(q.removed, isFalse);
    });

    test('an answer reads its question and answer', () {
      final q = TileQuote.fromJson(_answerQuote());
      expect(q.isAnswer, isTrue);
      expect(q.question, 'The song on repeat');
      expect(q.answer, 'Old Arijit');
    });

    test('a removed one carries nothing of the tile', () {
      final q = TileQuote.fromJson(_insightQuote(removed: true));
      expect(q.removed, isTrue);
      expect(q.displayValue, isNull);
      expect(q.caption, isNull);
    });

    test('a message carries it, and a plain message does not', () {
      expect(Message.fromJson(_message(tile: _insightQuote())).tile?.id, 'q1');
      expect(Message.fromJson(_message()).tile, isNull);
    });

    test('a page carries the openers in order', () {
      final page = MessagePage.fromJson({
        'messages': <Object>[],
        'has_more': false,
        'my_read_seq': 0,
        'their_read_seq': 0,
        'openers': [
          {'sender_id': 'me', 'tile': _insightQuote()},
          {'sender_id': 'her', 'tile': _answerQuote()},
        ],
      });
      expect([for (final o in page.openers) o.senderId], ['me', 'her']);
      expect(page.openers.last.tile.answer, 'Old Arijit');
    });

    test('a server that sends no openers reads as none', () {
      final page = MessagePage.fromJson({
        'messages': <Object>[],
        'has_more': false,
      });
      expect(page.openers, isEmpty);
    });

    testWidgets('a removed one says so and shows nothing of it', (tester) async {
      await tester.pumpWidget(
        _host(QuotedTile(tile: TileQuote.fromJson(_insightQuote(removed: true)))),
      );
      expect(find.text('This tile is no longer on their profile.'), findsOneWidget);
      expect(find.text('142'), findsNothing);
    });
  });

  group('a request', () {
    Map<String, Object?> request({Map<String, Object?>? tile}) => {
          'id': 'r1',
          'requested_at': '2026-09-27T10:00:00+00:00',
          'person': {
            'user_id': 'u',
            'first_name': 'Riya',
            'age': 27,
            'city': 'delhi_ncr',
            'photos': <Object>[],
            'tiles': <Object>[],
          },
          'tile': tile,
        };

    test('carries the tile it was about', () {
      final r = PendingRequest.fromJson(request(tile: _insightQuote()));
      expect(r.tile?.displayValue, '142');
    });

    test('a plain request has none', () {
      expect(PendingRequest.fromJson(request()).tile, isNull);
    });
  });

  group('sliding a tile', () {
    Future<List<int>> slide(WidgetTester tester, double dx) async {
      final fired = <int>[];
      await tester.pumpWidget(
        _host(
          SwipeToChat(
            onChat: () => fired.add(1),
            child: const ColoredBox(color: Colors.red),
          ),
        ),
      );
      await tester.drag(find.byType(ColoredBox).first, Offset(dx, 0));
      await tester.pumpAndSettle();
      return fired;
    }

    testWidgets('most of the way across sends at once', (tester) async {
      expect(await slide(tester, -240), [1]);
    });

    testWidgets('part of the way opens it, and the action sends', (tester) async {
      final fired = await slide(tester, -110);
      expect(fired, isEmpty);
      expect(find.text('Chat about this'), findsOneWidget);
      await tester.tap(find.text('Chat about this'));
      await tester.pumpAndSettle();
      expect(fired, [1]);
    });

    testWidgets('a nudge closes again and sends nothing', (tester) async {
      final fired = await slide(tester, -20);
      expect(fired, isEmpty);
      expect(find.text('Chat about this'), findsNothing);
    });

    testWidgets('sliding right does nothing', (tester) async {
      expect(await slide(tester, 200), isEmpty);
      expect(find.text('Chat about this'), findsNothing);
    });
  });
}
