import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/models/chat.dart';
import '../../../../shared/models/game.dart';
import '../../../../shared/widgets/buttons.dart';
import '../../../../shared/widgets/pressable.dart';
import 'game_sheets.dart';

/// A move in a game, in the chat.
///
/// Drawn from [game], the newest copy of the game the page holds, not from the
/// copy on [message]: a start card on screen should know once it has been
/// answered.
///
/// A card is small: one line names the game and whose turn it is, then the
/// question in full and its answers. A finished game shows its result where it
/// ended while nothing has been said after it ([latest]), playing a short
/// reveal if it ended while the chat was open ([reveal]). Once the chat moves
/// on it folds to one line, which opens the whole result in a glass sheet; its
/// start, further up, draws nothing.
///
/// Tic tac toe and Worduel are one live card each: the page draws only the
/// newest message of one, and this card is the game as it stands.
class GameBubble extends StatefulWidget {
  const GameBubble({
    required this.message,
    required this.game,
    required this.me,
    required this.theirName,
    required this.onPicks,
    required this.onGuess,
    required this.onText,
    required this.onMove,
    required this.onWord,
    this.busy = false,
    this.expanded = false,
    this.latest = false,
    this.reveal = false,
    this.onRevealed,
    this.onNewWord,
    super.key,
  });

  final Message message;
  final GameState game;
  final String me;
  final String theirName;
  final bool busy;

  /// In the result sheet: the whole game, never folded, and no card around it
  /// since the sheet is one.
  final bool expanded;

  /// Nothing has been said after this message: a game that ended here shows
  /// its result instead of folding.
  final bool latest;

  /// The game ended while the chat was open: its result plays its reveal, once,
  /// then [onRevealed] is called.
  final bool reveal;
  final VoidCallback? onRevealed;

  /// A finished Worduel: set a new word for the other person. The result
  /// sheet offers it; null, it is not offered.
  final VoidCallback? onNewWord;

  /// Their game, my turn: my pick on each card.
  final ValueChanged<List<int>> onPicks;

  /// Their two truths or their film, my turn: which one I think it is.
  final ValueChanged<int> onGuess;

  /// Their truth, my turn: my answer. Their own film: the name I type.
  final ValueChanged<String> onText;

  /// A board, my turn: the square I take.
  final ValueChanged<int> onMove;

  /// Their Worduel, my turn: my guess.
  final ValueChanged<String> onWord;

  @override
  State<GameBubble> createState() => _GameBubbleState();
}

class _GameBubbleState extends State<GameBubble>
    with SingleTickerProviderStateMixin {
  /// My picks so far on their rapid fire, before Send.
  List<int?>? _picks;

  /// What I am typing: a guess in their Worduel, or the name of their film.
  final _typed = TextEditingController();

  /// The reveal, while it plays. Without one, every result is drawn settled.
  AnimationController? _reveal;

  static const _revealFor = Duration(milliseconds: 1100);

  /// FLAMES: the full working is playing here, the first time (its own
  /// reveal) or because "See the working" was tapped.
  bool _working = false;

  @override
  void initState() {
    super.initState();
    // What is typed decides whether Guess shows.
    _typed.addListener(() => setState(() {}));
    _maybeReveal();
  }

  @override
  void didUpdateWidget(GameBubble old) {
    super.didUpdateWidget(old);
    // A guess that went through is on the grid now: start the next one empty.
    if (widget.game.guesses.length != old.game.guesses.length) _typed.clear();
    _maybeReveal();
  }

  void _maybeReveal() {
    if (!widget.reveal || !widget.game.done || _reveal != null) return;
    if (widget.game.kind == GameKind.flames) {
      // FLAMES' reveal is the whole working, which keeps its own time.
      if (!_working && !widget.expanded) _working = true;
      return;
    }
    _reveal = AnimationController(vsync: this, duration: _revealFor)
      ..addListener(() => setState(() {}))
      ..forward().whenComplete(() => widget.onRevealed?.call());
  }

  @override
  void dispose() {
    _reveal?.dispose();
    _typed.dispose();
    super.dispose();
  }

  /// How far the reveal has got, 0 to 1. A settled result is 1.
  double get _t => _reveal?.value ?? 1;

  /// The share of the reveal between [start] and [start] + [length], eased.
  double _step(double start, double length) =>
      Curves.easeOut.transform(((_t - start) / length).clamp(0.0, 1.0));

  GameState get _game => widget.game;
  bool get _mine => widget.message.senderId == widget.me;
  bool get _startedByMe => _game.startedByMe(widget.me);
  String get _name => widget.theirName;

  /// Whoever guesses or answers second, as the line names them.
  String get _guesser => _startedByMe ? _name : 'you';

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game.kind == GameKind.worduel &&
        _startedByMe &&
        !game.done &&
        !widget.expanded) {
      return _setterLine(game);
    }
    if (game.done && !widget.expanded) {
      // The start above where it ended has nothing left to say. Where it
      // ended, the result shows until the chat moves on, then folds.
      final ended = widget.message.gameAnswer ||
          game.kind == GameKind.flames ||
          (game.kind?.live ?? false);
      if (!ended) return const SizedBox.shrink();
      if (!widget.latest) return _folded(game);
    }
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _eyebrow(game),
        SizedBox(height: widget.expanded ? 10 : 6),
        _body(game),
      ],
    );
    if (widget.expanded) return content;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: _mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
            decoration: BoxDecoration(
              color: AppColors.row,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                color: _mine ? AppColors.fill : AppColors.bubbleThemEdge,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _body(GameState game) {
    if (game.kind == GameKind.flames) return _flames(game);
    if (game.kind == GameKind.ticTacToe) return _board(game);
    if (game.kind == GameKind.worduel) return _worduel(game);
    if (game.done) return _result(game);
    return _startedByMe ? _waiting(game) : _myTurn(game);
  }

  // The line at the top, and the folded line.

  /// Mine to play now: the line is lit.
  bool _myMove(GameState game) => game.myTurn(widget.me);

  /// What the line says after the game's name: nothing while a reveal plays,
  /// so the line never tells the ending first.
  String _status(GameState game) {
    if (game.done) return _working || _t < 1 ? '' : _summary(game);
    final mine = _myMove(game);
    switch (game.kind) {
      case GameKind.ticTacToe:
        final mark = _startedByMe ? 'X' : 'O';
        return mine
            ? 'your turn · you are $mark'
            : 'waiting for $_name · you are $mark';
      case GameKind.worduel:
        return _startedByMe ? '$_name is guessing your word' : 'your turn';
      default:
        if (!mine) return 'waiting for $_name';
        final own = game.cards.isNotEmpty && game.cards.first.own;
        return own ? '$_name wrote this · your turn' : 'your turn';
    }
  }

  /// How a finished game ended, in a few words.
  String _summary(GameState game) {
    switch (game.kind) {
      case GameKind.flames:
        return game.flames?.word ?? '';
      case GameKind.ticTacToe:
        if (game.winner == null) return 'a draw';
        return game.winner == (_startedByMe ? 'x' : 'o')
            ? 'you won'
            : '$_name won';
      case GameKind.worduel:
        return game.correct == true
            ? '$_guesser got it in ${game.guesses.length}'
            : '$_guesser ran out of tries';
      case GameKind.twoTruths:
        return game.guess != null && game.guess == game.lie
            ? '$_guesser spotted the lie'
            : '$_guesser missed the lie';
      case GameKind.guessMovie:
        final right = game.ownFilm
            ? game.correct == true
            : game.guess != null && game.guess == game.answer;
        return right ? '$_guesser got the film' : '$_guesser missed the film';
      case GameKind.truth:
        return 'both answered';
      default:
        final mine = _startedByMe ? game.starterPicks : game.replyPicks;
        final theirs = _startedByMe ? game.replyPicks : game.starterPicks;
        var same = 0;
        for (var i = 0; i < game.cards.length; i++) {
          if (_at(mine, i) != null && _at(mine, i) == _at(theirs, i)) same++;
        }
        if (game.cards.length != 1) {
          return 'matched $same of ${game.cards.length}';
        }
        final card = game.cards.first;
        final pick = _at(mine, 0);
        if (game.kind == GameKind.neverHaveIEver) {
          return _whoHas(pick, _at(theirs, 0));
        }
        return same == 1 && pick != null && pick < card.options.length
            ? 'you both said ${card.options[pick]}'
            : 'you differ';
    }
  }

  Widget _eyebrow(GameState game) {
    final lit = _myMove(game);
    final status = _status(game);
    final color = lit ? AppColors.accent : AppColors.label2;
    return Row(
      children: [
        Icon(GameIcon.iconFor(game.kind), size: 14, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            status.isEmpty ? game.title : '${game.title} · $status',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: color),
          ),
        ),
        if (game.kind == GameKind.worduel && !game.done)
          Text(
            _tries(game.guesses.length),
            semanticsLabel:
                '${Worduel.tries - game.guesses.length} tries left',
            style: AppText.caption.copyWith(color: AppColors.label3),
          ),
      ],
    );
  }

  /// Tries used and left, as dots.
  static String _tries(int used) =>
      '${'●' * used}${'○' * (Worduel.tries - used)}';

  /// My Worduel while they guess: one small line. My word in tiles until they
  /// guess; then their guesses as colour squares, which show how close they
  /// are without spelling out what they tried.
  Widget _setterLine(GameState game) {
    final tried = game.guesses.length;
    final close =
        tried > 0 && 'c'.allMatches(game.guesses.last.marks).length >= 3;
    final word = (game.word ?? '').toUpperCase();
    final headline = tried == 0
        ? 'Worduel sent to $_name'
        : close
            ? '$_name is close'
            : '$_name is guessing';
    final sub = tried == 0
        ? '${Worduel.tries} tries'
        : '$tried of ${Worduel.tries} · $word';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: _mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.row,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: _mine ? AppColors.fill : AppColors.bubbleThemEdge,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tried == 0)
                WorduelWord(word: word)
              else
                WorduelPath(guesses: game.guesses),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: AppText.footnote.copyWith(color: AppColors.label),
                  ),
                  Text(sub, style: AppText.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A finished game: one line, which opens the whole of it.
  Widget _folded(GameState game) {
    final line = '${game.title} · ${_summary(game)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: _mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Pressable(
          onTap: () => showGameResultSheet(
            context,
            child: GameBubble(
              message: widget.message,
              game: game,
              me: widget.me,
              theirName: widget.theirName,
              expanded: true,
              onNewWord: widget.onNewWord,
              onPicks: (_) {},
              onGuess: (_) {},
              onText: (_) {},
              onMove: (_) {},
              onWord: (_) {},
            ),
          ),
          semanticLabel: '$line. Open',
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.row,
                borderRadius: BorderRadius.circular(Radii.chip),
                border: Border.all(
                  color: _mine ? AppColors.fill : AppColors.bubbleThemEdge,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A Worduel shows how its last guess went, as squares.
                  if (game.kind == GameKind.worduel && game.guesses.isNotEmpty)
                    WorduelMarks(marks: game.guesses.last.marks, size: 10)
                  else
                    Icon(
                      GameIcon.iconFor(game.kind),
                      size: 14,
                      color: AppColors.accent,
                    ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: AppColors.label),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.label3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Waiting for them.

  Widget _waiting(GameState game) {
    if (game.kind == GameKind.truth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _question(game),
          _said('You', game.starterText),
        ],
      );
    }
    if (game.kind == GameKind.guessMovie) {
      final card = game.cards.isEmpty ? null : game.cards.first;
      final answer = game.answer;
      final film = game.film ??
          (card != null && answer != null && answer < card.options.length
              ? card.options[answer]
              : null);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _clue(card),
          if (film != null)
            Text(
              'You sent $film',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: AppColors.label2),
            ),
        ],
      );
    }
    if (game.kind == GameKind.twoTruths) {
      final lines = game.statements ?? const <String>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines.length; i++)
            _statement(lines[i], lie: game.lie == i),
        ],
      );
    }
    return _cards(game, picks: game.starterPicks, onPick: null);
  }

  // My turn.

  Widget _myTurn(GameState game) {
    if (game.kind == GameKind.truth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _question(game),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            // A button its own size: a MiniButton fills the width it is given.
            child: IntrinsicWidth(
              child: MiniButton(
                label: 'Answer to see theirs',
                busy: widget.busy,
                onPressed: () async {
                  final question =
                      game.cards.isEmpty ? '' : game.cards.first.text;
                  final text =
                      await showTruthSheet(context, question: question);
                  if (text != null) widget.onText(text);
                },
              ),
            ),
          ),
        ],
      );
    }
    if (game.ownFilm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _clue(game.cards.first),
          const SizedBox(height: 4),
          _typeIn(
            hint: 'Type the film',
            maxChars: 80,
            label: 'Guess',
            ready: _typed.text.trim().isNotEmpty,
            onSend: () => widget.onText(_typed.text.trim()),
          ),
        ],
      );
    }
    if (game.kind == GameKind.guessMovie) {
      final card = game.cards.isEmpty ? null : game.cards.first;
      final options = card?.options ?? const <String>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _clue(card),
          const SizedBox(height: 4),
          for (var r = 0; r < options.length; r += 2)
            Padding(
              padding: EdgeInsets.only(bottom: r + 2 < options.length ? 6 : 0),
              child: Row(
                children: [
                  for (var i = r; i < r + 2; i++) ...[
                    if (i > r) const SizedBox(width: 6),
                    Expanded(
                      child: i < options.length
                          ? ChoicePill(
                              label: options[i],
                              lit: false,
                              compact: true,
                              onTap:
                                  widget.busy ? null : () => widget.onGuess(i),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    }
    if (game.kind == GameKind.twoTruths) {
      final lines = game.statements ?? const <String>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Pressable(
                onTap: widget.busy ? null : () => widget.onGuess(i),
                semanticLabel: lines[i],
                child: _statementBox(lines[i], lit: false),
              ),
            ),
        ],
      );
    }
    // One card: a tap is the answer. Several: pick each, then send.
    if (game.cards.length == 1) {
      return _cards(
        game,
        picks: null,
        onPick: widget.busy ? null : (_, p) => widget.onPicks([p]),
      );
    }
    final picks = _picks ??= List<int?>.filled(game.cards.length, null);
    final ready = picks.every((p) => p != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cards(
          game,
          picks: picks,
          onPick: (i, p) => setState(() => picks[i] = p),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: IntrinsicWidth(
            child: MiniButton(
              label: 'Send picks',
              busy: widget.busy,
              onPressed: ready
                  ? () => widget.onPicks([for (final p in picks) p!])
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  /// The cards with their answers as pills. Rapid fire's "A or B?" goes
  /// unsaid: its two pills say it.
  Widget _cards(
    GameState game, {
    required List<int?>? picks,
    required void Function(int card, int pick)? onPick,
  }) {
    final rapid = game.kind == GameKind.rapidFire;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < game.cards.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == game.cards.length - 1 ? 0 : (rapid ? 6 : 10),
            ),
            child: CardChoice(
              card: game.cards[i],
              picked: picks == null || i >= picks.length ? null : picks[i],
              compact: true,
              showText: !rapid,
              onPick: onPick == null ? null : (p) => onPick(i, p),
            ),
          ),
      ],
    );
  }

  // Both answered: what the result sheet shows.

  Widget _result(GameState game) {
    if (game.kind == GameKind.twoTruths) return _truthsResult(game);
    if (game.kind == GameKind.truth) {
      final mine = _startedByMe ? game.starterText : game.replyText;
      final theirs = _startedByMe ? game.replyText : game.starterText;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _question(game),
          _said('You', mine),
          // Reveal: their answer fades in under mine.
          Opacity(opacity: _step(0.2, 0.4), child: _said(_name, theirs)),
        ],
      );
    }
    if (game.kind == GameKind.guessMovie) return _movieResult(game);
    final mine = _startedByMe ? game.starterPicks : game.replyPicks;
    final theirs = _startedByMe ? game.replyPicks : game.starterPicks;
    if (game.cards.length == 1) {
      final card = game.cards.first;
      if (game.kind == GameKind.neverHaveIEver) {
        return _hands(card, _at(mine, 0), _at(theirs, 0));
      }
      return _flipCards(card, _at(mine, 0), _at(theirs, 0));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < game.cards.length; i++)
          Padding(
            padding:
                EdgeInsets.only(bottom: i == game.cards.length - 1 ? 0 : 12),
            child: _both(game.cards[i], _at(mine, i), _at(theirs, i), i),
          ),
      ],
    );
  }

  /// A card of rapid fire, both answers. Reveal: theirs fade in a row at a
  /// time, then the ones that match light up.
  Widget _both(GameCard card, int? mine, int? theirs, int row) {
    String said(int? pick) =>
        pick != null && pick < card.options.length ? card.options[pick] : '?';
    final shown = _step(0.05 + row * 0.12, 0.25);
    final same = mine != null && mine == theirs && _t >= 0.65 + row * 0.04;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.text, style: AppText.footnote),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _answerChip('You', said(mine), same)),
            const SizedBox(width: 8),
            Expanded(
              child: Opacity(
                opacity: shown,
                child: Transform.translate(
                  offset: Offset(0, (1 - shown) * 4),
                  // Empty until it shows, or a longer answer's height would
                  // tell which it is.
                  child:
                      _answerChip(_name, shown > 0 ? said(theirs) : '', same),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Would you rather: a card each, face down, which flip to the answers; the
  /// same answer lights both.
  Widget _flipCards(GameCard card, int? mine, int? theirs) {
    String said(int? pick) =>
        pick != null && pick < card.options.length ? card.options[pick] : '?';
    final same = mine != null && mine == theirs;
    final settled = _t >= 0.75;
    Widget face(String who, String answer, double flip) {
      // Edge on halfway through: the answer is on the far side.
      final turned = flip >= 0.5;
      final lit = same && settled;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateY(math.sin(flip * math.pi) * math.pi / 2),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: lit ? AppColors.fill : AppColors.fill2,
            borderRadius: BorderRadius.circular(Radii.panel),
            border: Border.all(color: lit ? AppColors.fill : AppColors.hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                who,
                style: AppText.micro.copyWith(
                  color: lit ? AppColors.onAccent : AppColors.label2,
                ),
              ),
              Text(
                turned ? answer : '?',
                textAlign: TextAlign.center,
                style: AppText.footnote.copyWith(
                  color: lit ? AppColors.onAccent : AppColors.label,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.text, style: AppText.footnote),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: face('You', said(mine), _step(0.1, 0.35))),
            const SizedBox(width: 8),
            Expanded(child: face(_name, said(theirs), _step(0.25, 0.35))),
          ],
        ),
        _verdict(
          same ? 'You both said ${said(mine)}' : 'You two differ',
          lit: same,
        ),
      ],
    );
  }

  /// Never have I ever: a hand each, raised and lit in that person's colour
  /// only if they have; grey and down if they haven't.
  Widget _hands(GameCard card, int? mine, int? theirs) {
    // The first answer is always "I have".
    final iHave = mine == 0;
    final theyHave = theirs == 0;
    Widget hand(String who, bool have, Color color, double up) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.3 + 0.7 * up,
              child: Transform.translate(
                // Both start grey and down, so neither tells before it moves.
                offset: Offset(0, have ? (1 - up) * 6 : 6),
                child: Icon(
                  Icons.front_hand_rounded,
                  size: 32,
                  color: have
                      ? Color.lerp(AppColors.label4, color, up)
                      : AppColors.label4,
                  semanticLabel:
                      up == 0 ? who : '$who ${have ? 'have' : 'haven’t'}',
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(who, style: AppText.micro.copyWith(color: AppColors.label2)),
          ],
        );
    final verdict = _capital(_whoHas(mine, theirs));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.text, style: AppText.footnote),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            hand('You', iHave, AppColors.fill, _step(0.1, 0.3)),
            hand(_name, theyHave, AppColors.accent, _step(0.35, 0.3)),
          ],
        ),
        _verdict(verdict, lit: iHave && theyHave),
      ],
    );
  }

  /// Never have I ever, in words. The first answer is always "I have".
  String _whoHas(int? mine, int? theirs) {
    if (mine == 0 && theirs == 0) return 'you both have';
    if (mine == 0) return 'only you have';
    return theirs == 0 ? 'only $_name has' : 'neither of you has';
  }

  /// What a reveal ends on: no room is kept for it before, as how much room
  /// would tell the ending. The card grows by it as it fades in.
  Widget _unfold(double shown, Widget child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: shown,
          child: Opacity(opacity: shown, child: child),
        ),
      );

  /// The line under a reveal, once it has played.
  Widget _verdict(String text, {required bool lit}) => _unfold(
        _step(0.7, 0.3),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.footnote.copyWith(
              color: lit ? AppColors.accent : AppColors.label2,
            ),
          ),
        ),
      );

  Widget _answerChip(String who, String answer, bool same) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: same ? AppColors.fill : AppColors.fill2,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              who,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.micro.copyWith(
                color: same ? AppColors.onAccent : AppColors.label2,
              ),
            ),
            Text(
              answer,
              style: AppText.footnote.copyWith(
                color: same ? AppColors.onAccent : AppColors.label,
              ),
            ),
          ],
        ),
      );

  /// Reveal: the lie flips over and turns.
  Widget _truthsResult(GameState game) {
    final lines = game.statements ?? const <String>[];
    final flip = _step(0.2, 0.45);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++)
          if (game.lie == i)
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateX(math.sin(flip * math.pi) * math.pi / 2),
              child: _statement(
                lines[i],
                lie: flip >= 0.5,
                guessed: game.guess == i,
              ),
            )
          else
            _statement(lines[i], lie: false, guessed: game.guess == i),
      ],
    );
  }

  Widget _statement(String text, {required bool lie, bool guessed = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _statementBox(
          text,
          lit: lie,
          tag: lie ? 'Lie' : null,
          guessed: guessed,
        ),
      );

  Widget _statementBox(
    String text, {
    required bool lit,
    String? tag,
    bool guessed = false,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: lit ? AppColors.fill : AppColors.fill2,
          borderRadius: BorderRadius.circular(Radii.panel),
          border: Border.all(
            color: guessed ? AppColors.accent : AppColors.hairline,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppText.footnote.copyWith(
                  color: lit ? AppColors.onAccent : AppColors.label,
                ),
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Text(
                tag,
                style: AppText.micro.copyWith(color: AppColors.onAccent),
              ),
            ],
            if (guessed) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.touch_app_rounded,
                size: 14,
                color: AppColors.accent,
              ),
            ],
          ],
        ),
      );

  // Truth and the film.

  Widget _question(GameState game) => Text(
        game.cards.isEmpty ? '' : game.cards.first.text,
        style: AppText.callout.copyWith(color: AppColors.label),
      );

  Widget _said(String who, String? text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.fill2,
            borderRadius: BorderRadius.circular(Radii.panel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(who, style: AppText.micro.copyWith(color: AppColors.label2)),
              const SizedBox(height: 2),
              Text(
                text ?? '',
                style: AppText.footnote.copyWith(color: AppColors.label),
              ),
            ],
          ),
        ),
      );

  Widget _clue(GameCard? card) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          card?.text ?? '',
          textAlign: TextAlign.center,
          style: AppText.title2,
        ),
      );

  Widget _movieResult(GameState game) {
    final card = game.cards.isEmpty ? null : game.cards.first;
    if (game.ownFilm) {
      // Reveal: their guess types itself out, a tick or a cross, the title.
      final said = game.replyText ?? '';
      final typed = said.substring(0, (said.length * _step(0, 0.45)).round());
      final right = game.correct == true;
      final mark = _step(0.5, 0.2);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _clue(card),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '${_capital(_guesser)}: $typed',
                  style: AppText.callout.copyWith(color: AppColors.label),
                ),
              ),
              const SizedBox(width: 6),
              Transform.scale(
                scale: mark,
                child: Icon(
                  right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 18,
                  color: right ? AppColors.letterRight : AppColors.label3,
                ),
              ),
            ],
          ),
          _unfold(
            _step(0.65, 0.3),
            Text(
              right
                  ? 'It was ${game.film ?? ''}'
                  : '${_capital(_guesser)} said $said. It was '
                      '${game.film ?? ''}.',
              textAlign: TextAlign.center,
              style: AppText.footnote.copyWith(color: AppColors.label2),
            ),
          ),
        ],
      );
    }
    // Reveal: a wrong pick shakes, then the film lights up.
    final shake = _step(0, 0.35);
    final lit = _t >= 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _clue(card),
        const SizedBox(height: 4),
        for (var i = 0; i < (card?.options.length ?? 0); i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Transform.translate(
              offset: Offset(
                i == game.guess && i != game.answer
                    ? math.sin(shake * math.pi * 4) * 5 * (1 - shake)
                    : 0,
                0,
              ),
              child: _statementBox(
                card!.options[i],
                lit: lit && i == game.answer,
                tag: lit && i == game.answer ? 'The film' : null,
                guessed: i == game.guess,
              ),
            ),
          ),
      ],
    );
  }

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// A box to type into, with its button: the name of their film.
  Widget _typeIn({
    required String hint,
    required int maxChars,
    required String label,
    required bool ready,
    required VoidCallback onSend,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.panel),
      borderSide: const BorderSide(color: AppColors.hairline),
    );
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _typed,
            maxLength: maxChars,
            textCapitalization: TextCapitalization.words,
            style: AppText.footnote.copyWith(color: AppColors.label),
            cursorColor: AppColors.accent,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (ready && !widget.busy) onSend();
            },
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              hintText: hint,
              hintStyle: AppText.footnote.copyWith(color: AppColors.label3),
              filled: true,
              fillColor: AppColors.menu,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: border,
              enabledBorder: border,
              focusedBorder: border,
            ),
          ),
        ),
        const SizedBox(width: 8),
        MiniButton(
          label: label,
          busy: widget.busy,
          onPressed: ready ? onSend : null,
        ),
      ],
    );
  }

  // Worduel.

  /// The rows played so far and, on my turn, the row I am typing: the letters
  /// go straight into the tiles. Tapping the grid brings up the keyboard.
  /// Once over (in the result sheet): the word, the path to it in colour, and
  /// a new word to send back.
  Widget _worduel(GameState game) {
    if (game.done) return _worduelResult(game);
    final myTurn = _myMove(game);
    final typed = _typed.text.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (game.guesses.isEmpty && !myTurn)
          Text(
            'No guesses yet',
            textAlign: TextAlign.center,
            style: AppText.caption,
          )
        else
          Center(
            child: myTurn
                ? WorduelTyping(
                    controller: _typed,
                    guesses: game.guesses,
                    onSubmitted: (_) {
                      final word = _typed.text.trim().toLowerCase();
                      if (worduelWordReady(word) && !widget.busy) {
                        widget.onWord(word);
                      }
                    },
                  )
                : WorduelGrid(
                    guesses: game.guesses,
                    showEmpty: false,
                    tile: 30,
                  ),
          ),
        if (myTurn) ...[
          const SizedBox(height: 8),
          if (worduelWordReady(typed))
            Center(
              child: IntrinsicWidth(
                child: MiniButton(
                  label: 'Guess',
                  busy: widget.busy,
                  onPressed: () => widget.onWord(typed),
                ),
              ),
            )
          else
            Text(
              'Tap the tiles to type',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
        ],
      ],
    );
  }

  Widget _worduelResult(GameState game) {
    final newWord = widget.onNewWord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reveal: the word's tiles flip over one at a time.
        Center(
          child: WorduelWord(
            word: game.word ?? '',
            tile: 30,
            flipped: _t,
            color: game.correct == true
                ? AppColors.letterRight
                : AppColors.letterAbsent,
          ),
        ),
        // Then the rows: how many there are tells whether it was solved.
        _unfold(
          _step(0.8, 0.2),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(child: WorduelPath(guesses: game.guesses, size: 14)),
          ),
        ),
        if (newWord != null) ...[
          const SizedBox(height: 14),
          Center(
            child: IntrinsicWidth(
              child: MiniButton(
                label: 'Send a new word',
                onPressed: () {
                  // From the result sheet, close it first.
                  if (widget.expanded) Navigator.of(context).pop();
                  newWord();
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Tic tac toe.

  Widget _board(GameState game) {
    final myTurn = _myMove(game);
    return Center(
      child: TicTacToeBoard(
        board: game.board ?? '         ',
        line: game.line,
        // Reveal: the winning line draws across.
        drawn: _step(0.15, 0.5),
        size: widget.expanded ? 180 : 132,
        onTap: myTurn && !widget.busy ? widget.onMove : null,
      ),
    );
  }

  // FLAMES.

  /// The first time, live: the whole working, as it was done at school
  /// (FlamesWorking), with a Skip. After that, the letters with the crossed
  /// ones dimmed, the word, and "See the working" to play it again.
  Widget _flames(GameState game) {
    final result = game.flames;
    if (result == null) return const SizedBox.shrink();
    if (_working) {
      return FlamesWorking(
        result: result,
        autoplay: true,
        onDone: () {
          if (mounted) setState(() => _working = false);
          widget.onRevealed?.call();
        },
      );
    }
    final out = flamesOrder(result.left);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.names.join('  +  '),
          textAlign: TextAlign.center,
          style: AppText.footnote.copyWith(color: AppColors.label2),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, letter) in 'FLAMES'.split('').indexed)
              Builder(
                builder: (_) {
                  final step = out.indexOf(i);
                  final gone = step < 0 ? 0.0 : _step(0.08 + step * 0.11, 0.1);
                  final kept = letter == result.letter && _t >= 0.68;
                  return Opacity(
                    opacity: 1 - gone * 0.75,
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kept ? AppColors.fill : AppColors.fill2,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        letter,
                        style: AppText.bodyStrong.copyWith(
                          color: kept ? AppColors.onAccent : AppColors.label3,
                          decoration:
                              gone > 0.5 ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: _step(0.72, 0.28),
          child: Column(
            children: [
              Text(
                result.word,
                textAlign: TextAlign.center,
                style: AppText.title2,
              ),
              const SizedBox(height: 2),
              Text(
                result.line,
                textAlign: TextAlign.center,
                style: AppText.footnote.copyWith(color: AppColors.label2),
              ),
            ],
          ),
        ),
        if (result.left > 0)
          Center(
            child: TextActionButton(
              label: 'See the working',
              onPressed: () => setState(() => _working = true),
            ),
          ),
      ],
    );
  }

  static int? _at(List<int>? list, int i) =>
      list != null && i < list.length ? list[i] : null;
}
