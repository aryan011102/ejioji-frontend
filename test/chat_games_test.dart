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
        onText: (_) {},
        onMove: (_) {},
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
        onText: (_) {},
        onMove: (_) {},
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
        onText: (_) {},
        onMove: (_) {},
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
        onText: (_) {},
        onMove: (_) {},
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
        onText: (_) {},
        onMove: (_) {},
      ),
    );
    expect(find.text('Marriage'), findsOneWidget);
    expect(find.text('Arjun  +  Meera'), findsOneWidget);
  });

  // v2: truth, the film, tic tac toe.

  Map<String, Object?> v2(Map<String, Object?> fields) => {
        'id': 'g-2',
        'title': 'Game',
        'status': 'waiting',
        'started_by': her,
        'cards': <Object?>[],
        ...fields,
      };

  Widget card(
    Message m, {
    ValueChanged<int>? onGuess,
    ValueChanged<int>? onMove,
  }) =>
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: 'Priya',
        onPicks: (_) {},
        onGuess: onGuess ?? (_) {},
        onText: (_) {},
        onMove: onMove ?? (_) {},
      );

  test('a board copy with more marks wins, and done beats both', () {
    final early =
        GameState.fromJson(v2({'game': 'tic_tac_toe', 'board': 'x        '}));
    final later =
        GameState.fromJson(v2({'game': 'tic_tac_toe', 'board': 'x   o    '}));
    final over = GameState.fromJson(
      v2({
        'game': 'tic_tac_toe',
        'board': 'xxxoo    ',
        'status': 'done',
        'winner': 'x',
      }),
    );
    expect(later.newer(early), same(later));
    expect(early.newer(later), same(later));
    expect(later.newer(over), same(over));
    expect(over.newer(later), same(over));
  });

  testWidgets('my turn on a board: an empty square is a move', (tester) async {
    final m = Message.fromJson(
      message(v2({'game': 'tic_tac_toe', 'board': 'x        ', 'turn': me})),
    );
    int? cell;
    await pump(tester, card(m, onMove: (c) => cell = c));
    expect(find.text('Your turn'), findsOneWidget);
    expect(find.text('You are O'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Empty square 5'));
    expect(cell, 4);
  });

  testWidgets('their turn on a board: nothing moves', (tester) async {
    final m = Message.fromJson(
      message(v2({'game': 'tic_tac_toe', 'board': 'x   o    ', 'turn': her})),
    );
    await pump(tester, card(m, onMove: (_) => fail('not my turn')));
    expect(find.text('Waiting for Priya'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Empty square 2'));
  });

  testWidgets('a board that is over says who won', (tester) async {
    final m = Message.fromJson(
      message(
        v2({
          'game': 'tic_tac_toe',
          'board': 'xxxoo    ',
          'status': 'done',
          'winner': 'x',
          'line': [0, 1, 2],
        }),
        event: 'answered',
      ),
    );
    await pump(tester, card(m));
    // She started, so she is x: she won.
    expect(find.text('Priya won'), findsOneWidget);
  });

  testWidgets('their film, my guess: four titles to tap', (tester) async {
    final m = Message.fromJson(
      message(
        v2({
          'game': 'guess_movie',
          'cards': [
            {
              'key': '',
              'text': '🚂🌻💑',
              'options': [
                'Pardes',
                'Dilwale Dulhania Le Jayenge',
                'Mohabbatein',
                'Taal',
              ],
            },
          ],
        }),
      ),
    );
    int? guess;
    await pump(tester, card(m, onGuess: (g) => guess = g));
    await tester.tap(find.text('Dilwale Dulhania Le Jayenge'));
    expect(guess, 1);
  });

  testWidgets('truth answered: both answers show', (tester) async {
    final m = Message.fromJson(
      message(
        v2({
          'game': 'truth',
          'status': 'done',
          'cards': [
            {
              'key': 'truth_best_meal',
              'text': 'Best meal?',
              'options': <Object?>[],
            },
          ],
          'starter_text': 'Rajma chawal',
          'reply_text': 'Maggi',
        }),
        sender: me,
        event: 'answered',
      ),
    );
    await pump(tester, card(m));
    expect(find.text('Rajma chawal'), findsOneWidget);
    expect(find.text('Maggi'), findsOneWidget);
  });
}
