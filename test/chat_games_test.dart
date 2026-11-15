import 'package:ejioji/features/chats/presentation/games/game_bubble.dart';
import 'package:ejioji/shared/models/chat.dart';
import 'package:ejioji/shared/models/enums.dart';
import 'package:ejioji/shared/models/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Games in a chat: what the phone reads from the server, and what the card
/// draws on each side of each turn.
void main() {
  const me = 'me-1';
  const her = 'her-2';

  Map<String, Object?> game({
    String status = 'waiting',
    String startedBy = her,
    String kind = 'would_you_rather',
    List<int>? starterPicks,
    List<int>? replyPicks,
    Map<String, Object?>? flames,
  }) =>
      {
        'id': 'g-1',
        'game': kind,
        'title': 'Would you rather',
        'status': status,
        'started_by': startedBy,
        'cards': [
          {
            'key': 'wyr_hills_beach',
            'text': 'A holiday in the hills or by the beach?',
            'options': ['Hills', 'Beach'],
          },
        ],
        'starter_picks': starterPicks,
        'reply_picks': replyPicks,
        'statements': null,
        'lie': null,
        'guess': null,
        'flames': flames,
      };

  Map<String, Object?> message(
    Map<String, Object?> g, {
    String sender = her,
    String event = 'started',
  }) =>
      {
        'id': 'm-$event',
        'match_id': 'match-1',
        'seq': event == 'started' ? 1 : 2,
        'sender_id': sender,
        'client_id': 'c-$event',
        'kind': 'game',
        'text': 'Started Would you rather. Update the app to play.',
        'media': null,
        'tile': null,
        'sent_at': '2026-11-15T10:00:00Z',
        'game_event': event,
        'game': g,
      };

  test('a game message reads as a game, with what this reader may see', () {
    final m = Message.fromJson(message(game()));
    expect(m.kind, MessageKind.game);
    expect(m.gameAnswer, isFalse);
    expect(m.game!.kind, GameKind.wouldYouRather);
    expect(m.game!.done, isFalse);
    expect(m.game!.starterPicks, isNull);
    expect(m.game!.cards.single.options, ['Hills', 'Beach']);
  });

  test('a game this build does not know is still read, without a kind', () {
    final m = Message.fromJson(message(game(kind: 'chess')));
    expect(m.game!.kind, isNull);
  });

  test('a done game is never undone by a late waiting copy', () {
    final waiting = GameState.fromJson(game());
    final done = GameState.fromJson(
      game(status: 'done', starterPicks: [0], replyPicks: [1]),
    );
    expect(done.newer(waiting), same(done));
    expect(waiting.newer(done), same(done));
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
      );

  testWidgets('her game, my turn: one tap is my answer', (tester) async {
    final m = Message.fromJson(message(game()));
    List<int>? sent;
    await pump(
      tester,
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: 'Priya',
        onPicks: (p) => sent = p,
        onGuess: (_) {},
      ),
    );
    expect(find.textContaining('Pick yours to see theirs'), findsOneWidget);
    await tester.tap(find.text('Beach'));
    expect(sent, [1]);
  });

  testWidgets('my game, waiting: my pick shows and nothing can be tapped',
      (tester) async {
    final m = Message.fromJson(
      message(game(startedBy: me, starterPicks: [0]), sender: me),
    );
    await pump(
      tester,
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: 'Priya',
        onPicks: (_) => fail('the starter cannot answer'),
        onGuess: (_) {},
      ),
    );
    expect(find.textContaining('hidden until Priya plays'), findsOneWidget);
    await tester.tap(find.text('Beach'));
  });

  testWidgets('answered: both picks, and whether they match', (tester) async {
    final g = game(status: 'done', starterPicks: [1], replyPicks: [1]);
    final m = Message.fromJson(message(g, sender: me, event: 'answered'));
    await pump(
      tester,
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: 'Priya',
        onPicks: (_) {},
        onGuess: (_) {},
      ),
    );
    expect(find.text('You both said the same!'), findsOneWidget);
    expect(find.text('Beach'), findsNWidgets(2));
  });

  testWidgets('once answered, the start is one line', (tester) async {
    final g = game(status: 'done', starterPicks: [0], replyPicks: [1]);
    final m = Message.fromJson(message(g));
    await pump(
      tester,
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: 'Priya',
        onPicks: (_) {},
        onGuess: (_) {},
      ),
    );
    expect(find.text('Priya started Would you rather'), findsOneWidget);
    expect(find.text('Hills'), findsNothing);
  });

  testWidgets('FLAMES shows the word the server sent', (tester) async {
    final g = game(
      kind: 'flames',
      status: 'done',
      flames: {
        'names': ['Arjun', 'Meera'],
        'letter': 'M',
        'word': 'Marriage',
        'line': 'The cards have spoken.',
        'left': 6,
      },
    );
    final m = Message.fromJson(message(g));
    await pump(
      tester,
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: 'Meera',
        onPicks: (_) {},
        onGuess: (_) {},
      ),
    );
    expect(find.text('Marriage'), findsOneWidget);
    expect(find.text('Arjun  +  Meera'), findsOneWidget);
  });
}
