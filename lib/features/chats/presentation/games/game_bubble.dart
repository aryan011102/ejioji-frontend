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
/// answered. The answer is its own full card, since the start may be on an
/// older page that is not loaded; once answered, the start shrinks to a line.
///
/// Tic tac toe is one live board: the page draws only the newest message of a
/// board, and this card is the board as it stands.
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
    this.busy = false,
    super.key,
  });

  final Message message;
  final GameState game;
  final String me;
  final String theirName;
  final bool busy;

  /// Their game, my turn: my pick on each card.
  final ValueChanged<List<int>> onPicks;

  /// Their two truths or their film, my turn: which one I think it is.
  final ValueChanged<int> onGuess;

  /// Their truth, my turn: my answer.
  final ValueChanged<String> onText;

  /// A board, my turn: the square I take.
  final ValueChanged<int> onMove;

  @override
  State<GameBubble> createState() => _GameBubbleState();
}

class _GameBubbleState extends State<GameBubble> {
  /// My picks so far on their rapid fire, before Send.
  List<int?>? _picks;

  GameState get _game => widget.game;
  bool get _mine => widget.message.senderId == widget.me;
  bool get _startedByMe => _game.startedByMe(widget.me);

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final Widget body;
    if (game.kind == GameKind.flames) {
      body = _flames(game);
    } else if (game.kind == GameKind.ticTacToe) {
      body = _board(game);
    } else if (widget.message.gameAnswer) {
      body = _result(game);
    } else if (game.done) {
      return _startLine(game);
    } else if (_startedByMe) {
      body = _waiting(game);
    } else {
      body = _myTurn(game);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: _mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.row,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                color: _mine ? AppColors.fill : AppColors.bubbleThemEdge,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(game),
                const SizedBox(height: 10),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(GameState game) => Row(
        children: [
          GameIcon(game: game.kind, size: 26),
          const SizedBox(width: 8),
          Expanded(child: Text(game.title, style: AppText.bodyStrong)),
        ],
      );

  /// The start of a game that has been answered: the answer card below says
  /// everything, so this is one line.
  Widget _startLine(GameState game) {
    final who = _startedByMe ? 'You' : widget.theirName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(game: game.kind, size: 18),
            const SizedBox(width: 6),
            Text('$who started ${game.title}', style: AppText.micro),
          ],
        ),
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          text,
          style: AppText.footnote.copyWith(color: AppColors.label2),
        ),
      );

  // Waiting for them.

  Widget _waiting(GameState game) {
    if (game.kind == GameKind.truth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _question(game),
          _said('You', game.starterText),
          _note('Your answer is hidden until ${widget.theirName} answers.'),
        ],
      );
    }
    if (game.kind == GameKind.guessMovie) {
      final card = game.cards.isEmpty ? null : game.cards.first;
      final answer = game.answer;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _clue(card),
          if (card != null && answer != null && answer < card.options.length)
            Text(
              'You sent ${card.options[answer]}',
              textAlign: TextAlign.center,
              style: AppText.footnote.copyWith(color: AppColors.label2),
            ),
          _note('Waiting for ${widget.theirName} to guess.'),
        ],
      );
    }
    if (game.kind == GameKind.twoTruths) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < (game.statements ?? const []).length; i++)
            _statement(game.statements![i], lie: game.lie == i),
          _note('Waiting for ${widget.theirName} to spot the lie.'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < game.cards.length; i++)
          Padding(
            padding:
                EdgeInsets.only(bottom: i == game.cards.length - 1 ? 0 : 10),
            child: CardChoice(
              card: game.cards[i],
              picked: _at(game.starterPicks, i),
              onPick: null,
            ),
          ),
        _note('Your answer is hidden until ${widget.theirName} plays.'),
      ],
    );
  }

  // My turn.

  Widget _myTurn(GameState game) {
    if (game.kind == GameKind.truth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _question(game),
          _note('${widget.theirName} has answered. Write yours to see theirs.'),
          const SizedBox(height: 10),
          MiniButton(
            label: 'Answer',
            busy: widget.busy,
            onPressed: () async {
              final question = game.cards.isEmpty ? '' : game.cards.first.text;
              final text = await showTruthSheet(context, question: question);
              if (text != null) widget.onText(text);
            },
          ),
        ],
      );
    }
    if (game.kind == GameKind.guessMovie) {
      final card = game.cards.isEmpty ? null : game.cards.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _clue(card),
          const SizedBox(height: 8),
          for (var i = 0; i < (card?.options.length ?? 0); i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoicePill(
                label: card!.options[i],
                lit: false,
                onTap: widget.busy ? null : () => widget.onGuess(i),
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
          Text('Which one is the lie?', style: AppText.footnote),
          const SizedBox(height: 8),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardChoice(
            card: game.cards.first,
            picked: null,
            onPick: widget.busy ? null : (p) => widget.onPicks([p]),
          ),
          _note('${widget.theirName} has answered. Pick yours to see theirs.'),
        ],
      );
    }
    final picks = _picks ??= List<int?>.filled(game.cards.length, null);
    final ready = picks.every((p) => p != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < game.cards.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardChoice(
              card: game.cards[i],
              picked: picks[i],
              onPick: (p) => setState(() => picks[i] = p),
            ),
          ),
        MiniButton(
          label: 'Send my picks',
          busy: widget.busy,
          onPressed:
              ready ? () => widget.onPicks([for (final p in picks) p!]) : null,
        ),
      ],
    );
  }

  // Both answered.

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
          _said(widget.theirName, theirs),
        ],
      );
    }
    if (game.kind == GameKind.guessMovie) return _movieResult(game);
    final mine = _startedByMe ? game.starterPicks : game.replyPicks;
    final theirs = _startedByMe ? game.replyPicks : game.starterPicks;
    var same = 0;
    for (var i = 0; i < game.cards.length; i++) {
      if (_at(mine, i) != null && _at(mine, i) == _at(theirs, i)) same++;
    }
    final name = widget.theirName;
    final headline = game.cards.length == 1
        ? (same == 1
            ? 'You both said the same!'
            : 'You and $name differ on this one.')
        : 'You matched on $same of ${game.cards.length}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          headline,
          style: AppText.callout.copyWith(color: AppColors.accent),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < game.cards.length; i++)
          Padding(
            padding:
                EdgeInsets.only(bottom: i == game.cards.length - 1 ? 0 : 12),
            child: _both(game.cards[i], _at(mine, i), _at(theirs, i), name),
          ),
      ],
    );
  }

  Widget _both(GameCard card, int? mine, int? theirs, String name) {
    String said(int? pick) =>
        pick != null && pick < card.options.length ? card.options[pick] : '?';
    final same = mine != null && mine == theirs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.text, style: AppText.footnote),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _answerChip('You', said(mine), same)),
            const SizedBox(width: 8),
            Expanded(child: _answerChip(name, said(theirs), same)),
          ],
        ),
      ],
    );
  }

  Widget _answerChip(String who, String answer, bool same) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              style: AppText.callout.copyWith(
                color: same ? AppColors.onAccent : AppColors.label,
              ),
            ),
          ],
        ),
      );

  Widget _truthsResult(GameState game) {
    final lines = game.statements ?? const <String>[];
    final right = game.guess != null && game.guess == game.lie;
    final guesser = _startedByMe ? widget.theirName : 'You';
    final headline = right
        ? '$guesser spotted the lie!'
        : '$guesser guessed wrong. The lie was number ${(game.lie ?? 0) + 1}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          headline,
          style: AppText.callout.copyWith(color: AppColors.accent),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < lines.length; i++)
          _statement(lines[i], lie: game.lie == i, guessed: game.guess == i),
      ],
    );
  }

  Widget _statement(String text, {required bool lie, bool guessed = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: lit ? AppColors.fill : AppColors.fill2,
          borderRadius: BorderRadius.circular(Radii.row),
          border: Border.all(
            color: guessed ? AppColors.accent : AppColors.hairline,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppText.body.copyWith(
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
                size: 16,
                color: AppColors.accent,
              ),
            ],
          ],
        ),
      );

  // Truth and the film.

  Widget _question(GameState game) => Text(
        game.cards.isEmpty ? '' : game.cards.first.text,
        style: AppText.body,
      );

  Widget _said(String who, String? text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.fill2,
            borderRadius: BorderRadius.circular(Radii.row),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(who, style: AppText.micro.copyWith(color: AppColors.label2)),
              const SizedBox(height: 2),
              Text(text ?? '', style: AppText.body),
            ],
          ),
        ),
      );

  Widget _clue(GameCard? card) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          card?.text ?? '',
          textAlign: TextAlign.center,
          style: AppText.largeTitle,
        ),
      );

  Widget _movieResult(GameState game) {
    final card = game.cards.isEmpty ? null : game.cards.first;
    final right = game.guess != null && game.guess == game.answer;
    final guesser = _startedByMe ? widget.theirName : 'You';
    final film = card != null &&
            game.answer != null &&
            game.answer! < card.options.length
        ? card.options[game.answer!]
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _clue(card),
        Text(
          right
              ? '$guesser got it: $film!'
              : '$guesser guessed wrong. It was $film.',
          textAlign: TextAlign.center,
          style: AppText.callout.copyWith(color: AppColors.accent),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < (card?.options.length ?? 0); i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _statementBox(
              card!.options[i],
              lit: i == game.answer,
              tag: i == game.answer ? 'The film' : null,
              guessed: i == game.guess,
            ),
          ),
      ],
    );
  }

  // Tic tac toe.

  Widget _board(GameState game) {
    final mine = _startedByMe ? 'x' : 'o';
    final myTurn = !game.done && game.turn == widget.me;
    final String status;
    if (!game.done) {
      status = myTurn ? 'Your turn' : 'Waiting for ${widget.theirName}';
    } else if (game.winner == null) {
      status = 'A draw';
    } else {
      status = game.winner == mine ? 'You won!' : '${widget.theirName} won';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          status,
          textAlign: TextAlign.center,
          style: AppText.callout.copyWith(
            color: myTurn || game.done ? AppColors.accent : AppColors.label2,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TicTacToeBoard(
            board: game.board ?? '         ',
            line: game.line,
            onTap: myTurn && !widget.busy ? widget.onMove : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You are ${mine.toUpperCase()}',
          textAlign: TextAlign.center,
          style: AppText.micro,
        ),
      ],
    );
  }

  // FLAMES.

  Widget _flames(GameState game) {
    final result = game.flames;
    if (result == null) return const SizedBox.shrink();
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
            for (final letter in 'FLAMES'.split(''))
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: letter == result.letter
                      ? AppColors.fill
                      : AppColors.fill2,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  letter,
                  style: AppText.bodyStrong.copyWith(
                    color: letter == result.letter
                        ? AppColors.onAccent
                        : AppColors.label3,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(result.word, textAlign: TextAlign.center, style: AppText.title2),
        const SizedBox(height: 2),
        Text(
          result.line,
          textAlign: TextAlign.center,
          style: AppText.footnote.copyWith(color: AppColors.label2),
        ),
      ],
    );
  }

  static int? _at(List<int>? list, int i) =>
      list != null && i < list.length ? list[i] : null;
}
