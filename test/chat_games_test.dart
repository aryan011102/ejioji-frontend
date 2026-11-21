import 'package:ejioji/features/chats/presentation/games/game_bubble.dart';
import 'package:ejioji/features/chats/presentation/games/game_sheets.dart';
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

  Widget bubble(
    Message m, {
    String theirName = 'Priya',
    bool expanded = false,
    ValueChanged<List<int>>? onPicks,
    ValueChanged<int>? onGuess,
    ValueChanged<int>? onMove,
    ValueChanged<String>? onText,
    ValueChanged<String>? onWord,
  }) =>
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: theirName,
        expanded: expanded,
        onPicks: onPicks ?? (_) {},
        onGuess: onGuess ?? (_) {},
        onText: onText ?? (_) {},
        onMove: onMove ?? (_) {},
        onWord: onWord ?? (_) {},
      );

  testWidgets('her game, my turn: the full question, and one tap answers',
      (tester) async {
    final m = Message.fromJson(message(game()));
    List<int>? sent;
    await pump(tester, bubble(m, onPicks: (p) => sent = p));
    expect(find.text('Would you rather · your turn'), findsOneWidget);
    expect(
      find.text('A holiday in the hills or by the beach?'),
      findsOneWidget,
    );
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
      bubble(m, onPicks: (_) => fail('the starter cannot answer')),
    );
    expect(find.text('Would you rather · waiting for Priya'), findsOneWidget);
    await tester.tap(find.text('Beach'));
  });

  testWidgets('answered: folds to one line, which opens the result',
      (tester) async {
    final g = game(status: 'done', starterPicks: [1], replyPicks: [1]);
    final m = Message.fromJson(message(g, sender: me, event: 'answered'));
    await pump(tester, bubble(m));
    expect(
      find.text('Would you rather · you both said Beach'),
      findsOneWidget,
    );
    expect(find.text('Hills'), findsNothing);
    await tester.tap(find.text('Would you rather · you both said Beach'));
    await tester.pumpAndSettle();
    expect(find.text('Beach'), findsNWidgets(2));
    expect(find.text('Priya'), findsOneWidget);
  });

  testWidgets('once answered, the start says nothing more', (tester) async {
    final g = game(status: 'done', starterPicks: [0], replyPicks: [1]);
    final m = Message.fromJson(message(g));
    await pump(tester, bubble(m));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('FLAMES folds to its word, and opens to the names',
      (tester) async {
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
    await pump(tester, bubble(m, theirName: 'Meera'));
    expect(find.text('Would you rather · Marriage'), findsOneWidget);
    await pump(tester, bubble(m, theirName: 'Meera', expanded: true));
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

  test('whose turn it is: answering their game, or a move on mine', () {
    final theirs = GameState.fromJson(v2({'game': 'truth'}));
    expect(theirs.myTurn(me), isTrue);
    expect(theirs.myTurn(her), isFalse);
    final board = GameState.fromJson(v2({'game': 'tic_tac_toe', 'turn': her}));
    expect(board.myTurn(me), isFalse);
    expect(board.myTurn(her), isTrue);
    final flames = GameState.fromJson(v2({'game': 'flames'}));
    expect(flames.myTurn(me), isFalse);
  });

  testWidgets('my turn on a board: an empty square is a move', (tester) async {
    final m = Message.fromJson(
      message(v2({'game': 'tic_tac_toe', 'board': 'x        ', 'turn': me})),
    );
    int? cell;
    await pump(tester, bubble(m, onMove: (c) => cell = c));
    expect(find.text('Game · your turn · you are O'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Empty square 5'));
    expect(cell, 4);
  });

  testWidgets('their turn on a board: nothing moves', (tester) async {
    final m = Message.fromJson(
      message(v2({'game': 'tic_tac_toe', 'board': 'x   o    ', 'turn': her})),
    );
    await pump(tester, bubble(m, onMove: (_) => fail('not my turn')));
    expect(
      find.text('Game · waiting for Priya · you are O'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Empty square 2'));
  });

  testWidgets('a board that is over folds to who won', (tester) async {
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
    await pump(tester, bubble(m));
    // She started, so she is x: she won.
    expect(find.text('Game · Priya won'), findsOneWidget);
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
    await pump(tester, bubble(m, onGuess: (g) => guess = g));
    await tester.tap(find.text('Dilwale Dulhania Le Jayenge'));
    expect(guess, 1);
  });

  testWidgets('truth answered: both answers show in the result',
      (tester) async {
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
    await pump(tester, bubble(m));
    expect(find.text('Game · both answered'), findsOneWidget);
    await pump(tester, bubble(m, expanded: true));
    expect(find.text('Rajma chawal'), findsOneWidget);
    expect(find.text('Maggi'), findsOneWidget);
  });

  // v3: your own cards, and Worduel.

  test('a card of my own goes to the server as written, keys as they were', () {
    const own = OwnCard(text: 'Golgappe or dahi puri?', options: ['G', 'D']);
    expect(own.toJson(), {
      'text': 'Golgappe or dahi puri?',
      'options': ['G', 'D'],
    });
    expect(const OwnCard(text: 'mango').toJson(), {'text': 'mango'});
    final rapid = const OwnCard(options: ['Jalebi', 'Rasgulla'])
        .preview(GameKind.rapidFire);
    expect(rapid.text, 'Jalebi or Rasgulla?');
    final never =
        const OwnCard(text: 'eaten pani puri').preview(GameKind.neverHaveIEver);
    expect(never.text, 'Never have I ever eaten pani puri.');
    expect(never.own, isTrue);
  });

  Map<String, Object?> ownFilm(Map<String, Object?> fields) => v2({
        'game': 'guess_movie',
        'cards': [
          {'key': 'own_0', 'text': '🦁👑', 'options': <Object?>[], 'own': true},
        ],
        ...fields,
      });

  test('a card the server says is theirs reads as their own', () {
    final g = GameState.fromJson(ownFilm({}));
    expect(g.cards.single.own, isTrue);
    expect(g.ownFilm, isTrue);
    expect(g.film, isNull);
  });

  testWidgets('their own film, my turn: I type its name', (tester) async {
    final m = Message.fromJson(message(ownFilm({})));
    String? typed;
    await pump(tester, bubble(m, onText: (t) => typed = t));
    expect(find.text('Game · Priya wrote this · your turn'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  The Lion King ');
    await tester.pump();
    await tester.tap(find.text('Guess'));
    expect(typed, 'The Lion King');
  });

  testWidgets('their own film, guessed: what was said and what it was',
      (tester) async {
    final m = Message.fromJson(
      message(
        ownFilm({
          'status': 'done',
          'film': 'The Lion King',
          'reply_text': 'Jungle Book',
          'correct': false,
        }),
        sender: me,
        event: 'answered',
      ),
    );
    await pump(tester, bubble(m));
    expect(find.text('Game · you missed the film'), findsOneWidget);
    await pump(tester, bubble(m, expanded: true));
    expect(
      find.text('You said Jungle Book. It was The Lion King.'),
      findsOneWidget,
    );
  });

  Map<String, Object?> worduel(Map<String, Object?> fields) => v2({
        'game': 'worduel',
        'title': 'Worduel',
        'guesses': [
          {'word': 'salty', 'marks': 'acaaa'},
        ],
        'turn': me,
        ...fields,
      });

  testWidgets('their Worduel, my turn: letters go into the tiles',
      (tester) async {
    final m = Message.fromJson(message(worduel({})));
    String? sent;
    await pump(tester, bubble(m, onWord: (w) => sent = w));
    expect(find.text('Worduel · your turn'), findsOneWidget);
    expect(find.text('●○○○○○'), findsOneWidget);
    expect(find.bySemanticsLabel('A, right place'), findsOneWidget);
    expect(find.bySemanticsLabel('S, not in it'), findsOneWidget);
    expect(find.text('Tap the tiles to type'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'mang');
    await tester.pump();
    // The letters show in the row being typed, and there is no Guess yet.
    expect(find.text('G'), findsOneWidget);
    expect(find.text('Guess'), findsNothing);
    await tester.enterText(find.byType(TextField), 'MANGO');
    await tester.pump();
    await tester.tap(find.text('Guess'));
    expect(sent, 'mango');
  });

  testWidgets('my Worduel, sent: one line with my word', (tester) async {
    final m = Message.fromJson(
      message(
        worduel({
          'started_by': me,
          'turn': her,
          'word': 'mango',
          'guesses': <Object?>[],
        }),
        sender: me,
      ),
    );
    await pump(tester, bubble(m));
    expect(find.text('Worduel sent to Priya'), findsOneWidget);
    expect(find.text('6 tries'), findsOneWidget);
    expect(find.bySemanticsLabel('The word: MANGO'), findsOneWidget);
  });

  testWidgets('my Worduel, their turn: their rows as colour, nothing typed',
      (tester) async {
    final m = Message.fromJson(
      message(
        worduel({
          'started_by': me,
          'turn': her,
          'word': 'mango',
          'guesses': [
            {'word': 'salty', 'marks': 'acaaa'},
            {'word': 'macro', 'marks': 'ccaac'},
          ],
        }),
        sender: her,
        event: 'moved',
      ),
    );
    await pump(
      tester,
      bubble(m, onWord: (_) => fail('the setter never guesses')),
    );
    expect(find.text('Priya is close'), findsOneWidget);
    expect(find.text('2 of 6 · MANGO'), findsOneWidget);
    // Her guesses as colour only: their letters are not shown to me here.
    expect(find.text('SALTY'), findsNothing);
    expect(find.text('S'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Guess 1: 1 in the right place. Guess 2: 3 in the right place',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  Message finished() => Message.fromJson(
        message(
          worduel({
            'status': 'done',
            'turn': null,
            'word': 'mango',
            'correct': true,
            'guesses': [
              {'word': 'salty', 'marks': 'acaaa'},
              {'word': 'mango', 'marks': 'ccccc'},
            ],
          }),
          sender: me,
          event: 'answered',
        ),
      );

  testWidgets('a Worduel that is over folds to how it went', (tester) async {
    await pump(tester, bubble(finished()));
    expect(find.text('Worduel · you got it in 2'), findsOneWidget);
    await pump(tester, bubble(finished(), expanded: true));
    expect(find.bySemanticsLabel('The word: MANGO'), findsOneWidget);
    // No way to send another unless the page offers one.
    expect(find.text('Send a new word'), findsNothing);
  });

  testWidgets('a finished Worduel opens to send a new word', (tester) async {
    var asked = 0;
    final m = finished();
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
        onWord: (_) {},
        onNewWord: () => asked++,
      ),
    );
    await tester.tap(find.text('Worduel · you got it in 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send a new word'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    // The result sheet closed on the way.
    expect(find.text('Send a new word'), findsNothing);
  });

  Future<Object?> setWord(
    WidgetTester tester,
    Future<void> Function() act,
  ) async {
    Object? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => sent = await showWorduelStartSheet(
                context,
                words: const [
                  GameCard(key: 'wd_chess', text: 'chess', options: []),
                  GameCard(key: 'wd_pyaar', text: 'pyaar', options: []),
                ],
                theirName: 'Priya',
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Set a word for Priya'), findsOneWidget);
    await act();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    return sent;
  }

  testWidgets('setting a Worduel: a suggestion tapped fills the tiles',
      (tester) async {
    final sent = await setWord(tester, () async {
      await tester.tap(find.text('PYAAR'));
      await tester.pump();
      expect(find.text('Y'), findsOneWidget);
    });
    expect(sent, 'wd_pyaar');
  });

  testWidgets('setting a Worduel: a typed word is my own', (tester) async {
    final sent = await setWord(tester, () async {
      await tester.enterText(find.byType(TextField), 'mango');
      await tester.pump();
    });
    expect(sent, isA<OwnCard>());
    expect((sent! as OwnCard).text, 'mango');
  });

  test('a Worduel copy with more guesses wins', () {
    final early = GameState.fromJson(worduel({}));
    final later = GameState.fromJson(
      worduel({
        'guesses': [
          {'word': 'salty', 'marks': 'acaaa'},
          {'word': 'lemon', 'marks': 'apapa'},
        ],
      }),
    );
    expect(early.newer(later), same(later));
    expect(later.newer(early), same(later));
  });

  Future<GameKind?> openList(
    WidgetTester tester, {
    required int waiting,
    Finder? tap,
  }) async {
    GameKind? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showGamesSheet(
                context,
                waiting: waiting,
                theirName: 'Priya',
              ),
              child: const Text('Play'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    if (tap != null) {
      await tester.ensureVisible(tap);
      await tester.pumpAndSettle();
      await tester.tap(tap, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    return picked;
  }

  testWidgets('the games list says how many already wait on them',
      (tester) async {
    await openList(tester, waiting: 3);
    expect(find.text('You have 3 games waiting on Priya.'), findsOneWidget);
  });

  testWidgets('at the limit, games that wait cannot start', (tester) async {
    expect(
      await openList(tester, waiting: 5, tap: find.text('Worduel')),
      isNull,
    );
    expect(
      find.text(
        'You have 5 games waiting on Priya. Once Priya plays one, you can '
        'start another.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('at the limit, FLAMES still starts: it waits on nobody',
      (tester) async {
    expect(
      await openList(tester, waiting: 5, tap: find.text('FLAMES')),
      GameKind.flames,
    );
  });

  testWidgets('the games list: names only, and no Truth to start',
      (tester) async {
    GameKind? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showGamesSheet(context),
              child: const Text('Play'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Play a game'), findsOneWidget);
    expect(find.text('Worduel'), findsOneWidget);
    expect(find.text('FLAMES'), findsOneWidget);
    expect(find.text('Truth'), findsNothing);
    expect(find.textContaining('six tries'), findsNothing);
    await tester.tap(find.text('Worduel'));
    await tester.pumpAndSettle();
    expect(picked, GameKind.worduel);
  });

  // Results: open while nothing has been said after them, and a reveal.

  testWidgets('their Worduel: a tap on the tiles brings up the keyboard',
      (tester) async {
    final m = Message.fromJson(message(worduel({})));
    await pump(tester, bubble(m));
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.bySemanticsLabel(RegExp('^Type your word')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byType(TextField), 'ma');
    await tester.pump();
    expect(find.text('M'), findsOneWidget);
  });

  test('FLAMES crosses out in the order the server counts', () {
    // The server's worked example (test_chat_games.py): a count of 5 crosses
    // out E, M, S, L, A and leaves F.
    expect(flamesOrder(5), [4, 3, 5, 1, 2]);
    expect(flamesOrder(0), isEmpty);
    // Each round counts 5 from where the last stopped.
    expect(flamesRounds(5).first.hops, [0, 1, 2, 3, 4]);
  });

  test('FLAMES crosses out shared letters one for one, as the server does', () {
    final arjun = flamesLetters('Arjun');
    final priya = flamesLetters('Priya');
    expect(arjun, ['a', 'r', 'j', 'u', 'n']);
    expect(flamesPairs(arjun, priya), [(0, 4), (1, 1)]);
    // Accents off, case folded, anything else dropped.
    expect(flamesLetters('Zoë-Ann'), ['z', 'o', 'e', 'a', 'n', 'n']);
    // One for one: two a's against one cross out one pair.
    expect(flamesPairs(flamesLetters('Aara'), flamesLetters('Ram')).length, 2);
  });

  testWidgets('FLAMES, live: the whole working plays, then the result',
      (tester) async {
    var revealed = 0;
    final m = Message.fromJson(
      message(
        {
          ...game(kind: 'flames', status: 'done'),
          'title': 'FLAMES',
          'flames': {
            'names': ['Arjun', 'Priya'],
            'letter': 'M',
            'word': 'Marriage',
            'line': 'The cards have spoken.',
            'left': 6,
          },
        },
      ),
    );
    await pump(
      tester,
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: 'Priya',
        latest: true,
        reveal: true,
        onRevealed: () => revealed++,
        onPicks: (_) {},
        onGuess: (_) {},
        onText: (_) {},
        onMove: (_) {},
        onWord: (_) {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Cross out the letters both names share, one for one.'),
      findsOneWidget,
    );
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(revealed, 1);
    // Settled: the short result, and the working on a tap.
    expect(find.text('Marriage'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.text('See the working'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Skip'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('See the working'), findsOneWidget);
  });

  Message answered(Map<String, Object?> g) =>
      Message.fromJson(message(g, sender: me, event: 'answered'));

  Widget latest(Message m, {bool reveal = false, VoidCallback? onRevealed}) =>
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: 'Priya',
        latest: true,
        reveal: reveal,
        onRevealed: onRevealed,
        onPicks: (_) {},
        onGuess: (_) {},
        onText: (_) {},
        onMove: (_) {},
        onWord: (_) {},
      );

  testWidgets('a result stays open while nothing has been said after it',
      (tester) async {
    final m =
        answered(game(status: 'done', starterPicks: [1], replyPicks: [1]));
    await pump(tester, latest(m));
    // Two cards turned over, both lit, and the verdict.
    expect(find.text('Beach'), findsNWidgets(2));
    expect(find.text('You both said Beach'), findsOneWidget);
    // The same message once the chat has moved on: one line.
    await pump(tester, bubble(m));
    expect(find.text('You both said Beach'), findsNothing);
    expect(
      find.text('Would you rather · you both said Beach'),
      findsOneWidget,
    );
  });

  testWidgets('never have I ever: a hand for each, lit only for I have',
      (tester) async {
    Map<String, Object?> never(int mine, int hers) => {
          ...game(
            status: 'done',
            kind: 'never_have_i_ever',
            starterPicks: [hers],
            replyPicks: [mine],
          ),
          'cards': [
            {
              'key': 'nhie_missed_flight',
              'text': 'Never have I ever missed a flight or a train.',
              'options': ['I have', 'I haven’t'],
            },
          ],
        };
    await pump(tester, latest(answered(never(0, 0))));
    expect(find.text('You both have'), findsOneWidget);
    expect(find.bySemanticsLabel('You have'), findsOneWidget);
    expect(find.bySemanticsLabel('Priya have'), findsOneWidget);
    await pump(tester, latest(answered(never(0, 1))));
    expect(find.text('Only you have'), findsOneWidget);
    await pump(tester, latest(answered(never(1, 0))));
    expect(find.text('Only Priya has'), findsOneWidget);
    await pump(tester, latest(answered(never(1, 1))));
    expect(find.text('Neither of you has'), findsOneWidget);
  });

  testWidgets('a reveal plays once, then says so', (tester) async {
    var revealed = 0;
    final m =
        answered(game(status: 'done', starterPicks: [0], replyPicks: [1]));
    await pump(
      tester,
      latest(m, reveal: true, onRevealed: () => revealed++),
    );
    // Partway: the cards have not turned yet.
    expect(find.text('?'), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(revealed, 1);
    expect(find.text('You two differ'), findsOneWidget);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('a finished Worduel in the chat sends a new word in place',
      (tester) async {
    var asked = 0;
    final m = finished();
    await pump(
      tester,
      GameBubble(
        message: m,
        game: m.game!,
        me: me,
        theirName: 'Priya',
        latest: true,
        onPicks: (_) {},
        onGuess: (_) {},
        onText: (_) {},
        onMove: (_) {},
        onWord: (_) {},
        onNewWord: () => asked++,
      ),
    );
    await tester.tap(find.text('Send a new word'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    // Nothing was closed on the way: the chat is still there.
    expect(find.text('Send a new word'), findsOneWidget);
  });
}
