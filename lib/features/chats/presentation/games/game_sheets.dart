import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/models/game.dart';
import '../../../../shared/widgets/buttons.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../../shared/widgets/sheets.dart';

/// The games, like the apps row in iMessage: tap one to play it in this chat.
Future<GameKind?> showGamesSheet(BuildContext context) {
  return showAppSheet<GameKind>(
    context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Play a game', style: AppText.title3),
        const SizedBox(height: 4),
        Text(
          'You go first. They see your answer once they have played.',
          style: AppText.footnote.copyWith(color: AppColors.label2),
        ),
        const SizedBox(height: 14),
        for (final game in GameKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Pressable(
              onTap: () => Navigator.of(sheetContext).pop(game),
              semanticLabel: game.title,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.menu,
                  borderRadius: BorderRadius.circular(Radii.row),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    GameIcon(game: game),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(game.title, style: AppText.bodyStrong),
                          const SizedBox(height: 2),
                          Text(
                            game.pitch,
                            style: AppText.footnote
                                .copyWith(color: AppColors.label2),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.label3),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The round mark each game wears in the list and on its card.
class GameIcon extends StatelessWidget {
  const GameIcon({required this.game, this.size = 36, super.key});

  final GameKind? game;
  final double size;

  IconData get _icon => switch (game) {
        GameKind.wouldYouRather => Icons.alt_route_rounded,
        GameKind.rapidFire => Icons.bolt_rounded,
        GameKind.neverHaveIEver => Icons.front_hand_rounded,
        GameKind.twoTruths => Icons.psychology_alt_rounded,
        GameKind.flames => Icons.local_fire_department_rounded,
        GameKind.truth => Icons.chat_bubble_outline_rounded,
        GameKind.guessMovie => Icons.movie_outlined,
        GameKind.ticTacToe => Icons.grid_3x3_rounded,
        GameKind.worduel => Icons.spellcheck_rounded,
        null => Icons.casino_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          const BoxDecoration(color: AppColors.fill, shape: BoxShape.circle),
      child: Icon(_icon, size: size * 0.55, color: AppColors.onAccent),
    );
  }
}

/// The cards you were dealt, any of them swapped for one you write, and your
/// pick on each, in order. Each card is a dealt key or an [OwnCard]. Null if
/// they back out.
Future<(List<Object>, List<int>)?> showCardsSheet(
  BuildContext context, {
  required GameKind game,
  required List<GameCard> cards,
}) {
  return showAppSheet<(List<Object>, List<int>)>(
    context,
    builder: (_) => _CardsAnswer(game: game, cards: cards),
  );
}

class _CardsAnswer extends StatefulWidget {
  const _CardsAnswer({required this.game, required this.cards});

  final GameKind game;
  final List<GameCard> cards;

  @override
  State<_CardsAnswer> createState() => _CardsAnswerState();
}

class _CardsAnswerState extends State<_CardsAnswer> {
  late final List<int?> _picks = List<int?>.filled(widget.cards.length, null);

  /// The cards written in place of dealt ones, by place.
  final _own = <int, OwnCard>{};

  Future<void> _writeOwn(int i) async {
    final own =
        await showOwnCardSheet(context, game: widget.game, initial: _own[i]);
    if (own == null || !mounted) return;
    setState(() {
      _own[i] = own;
      _picks[i] = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _picks.every((p) => p != null);
    final shown = [
      for (var i = 0; i < widget.cards.length; i++)
        _own[i]?.preview(widget.game) ?? widget.cards[i],
    ];
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GameIcon(game: widget.game, size: 30),
              const SizedBox(width: 10),
              Text(widget.game.title, style: AppText.title3),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CardChoice(
                            card: shown[i],
                            picked: _picks[i],
                            onPick: (p) => setState(() => _picks[i] = p),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextActionButton(
                              label: _own.containsKey(i)
                                  ? 'Edit yours'
                                  : 'Write your own',
                              onPressed: () => _writeOwn(i),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          PrimaryButton(
            label: 'Send',
            onPressed: ready
                ? () => Navigator.of(context).pop(
                      (
                        [
                          for (var i = 0; i < widget.cards.length; i++)
                            _own[i] ?? widget.cards[i].key,
                        ],
                        [for (final p in _picks) p!],
                      ),
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

/// A card's question with its two answers as pills; [picked] is lit.
class CardChoice extends StatelessWidget {
  const CardChoice({
    required this.card,
    required this.picked,
    required this.onPick,
    super.key,
  });

  final GameCard card;
  final int? picked;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.text, style: AppText.body),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var o = 0; o < card.options.length; o++) ...[
              if (o > 0) const SizedBox(width: 8),
              Expanded(
                child: ChoicePill(
                  label: card.options[o],
                  lit: picked == o,
                  onTap: onPick == null ? null : () => onPick!(o),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class ChoicePill extends StatelessWidget {
  const ChoicePill({
    required this.label,
    required this.lit,
    this.onTap,
    super.key,
  });

  final String label;
  final bool lit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lit ? AppColors.fill : AppColors.fill2,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: lit ? AppColors.fill : AppColors.hairline),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppText.callout.copyWith(
            color: lit ? AppColors.onAccent : AppColors.label,
          ),
        ),
      ),
    );
  }
}

/// Three things about you, and which one is the lie.
Future<(List<String>, int)?> showTwoTruthsSheet(BuildContext context) {
  return showAppSheet<(List<String>, int)>(
    context,
    builder: (_) => const _TwoTruths(),
  );
}

class _TwoTruths extends StatefulWidget {
  const _TwoTruths();

  @override
  State<_TwoTruths> createState() => _TwoTruthsState();
}

class _TwoTruthsState extends State<_TwoTruths> {
  /// The server's limit for each one.
  static const _maxChars = 200;
  final _fields = List.generate(3, (_) => TextEditingController());
  int? _lie;

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _lie != null && _fields.every((f) => f.text.trim().isNotEmpty);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.row),
      borderSide: const BorderSide(color: AppColors.hairline),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const GameIcon(game: GameKind.twoTruths, size: 30),
                const SizedBox(width: 10),
                Text(GameKind.twoTruths.title, style: AppText.title3),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Write two true things and one that is not. Tap Lie on the one '
              'that is made up.',
              style: AppText.footnote.copyWith(color: AppColors.label2),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fields[i],
                        maxLength: _maxChars,
                        maxLines: 3,
                        minLines: 1,
                        style: AppText.body,
                        cursorColor: AppColors.accent,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Something about you',
                          hintStyle:
                              AppText.body.copyWith(color: AppColors.label3),
                          filled: true,
                          fillColor: AppColors.menu,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: ChoicePill(
                        label: 'Lie',
                        lit: _lie == i,
                        onTap: () => setState(() => _lie = i),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            PrimaryButton(
              label: 'Send',
              onPressed: ready
                  ? () => Navigator.of(context).pop(
                        (
                          [for (final f in _fields) f.text.trim()],
                          _lie!,
                        ),
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Truth: the question, and your answer in your own words. Null if they back
/// out.
Future<String?> showTruthSheet(
  BuildContext context, {
  required String question,
}) async {
  final answered = await showAppSheet<(OwnCard?, String)>(
    context,
    builder: (_) => _TruthAnswer(question: question),
  );
  return answered?.$2;
}

/// Truth, for the starter: the question dealt or one of their own, and their
/// answer. Null if they back out.
Future<(OwnCard?, String)?> showTruthStartSheet(
  BuildContext context, {
  required String question,
}) {
  return showAppSheet<(OwnCard?, String)>(
    context,
    builder: (_) => _TruthAnswer(question: question, canWriteOwn: true),
  );
}

class _TruthAnswer extends StatefulWidget {
  const _TruthAnswer({required this.question, this.canWriteOwn = false});

  final String question;
  final bool canWriteOwn;

  @override
  State<_TruthAnswer> createState() => _TruthAnswerState();
}

class _TruthAnswerState extends State<_TruthAnswer> {
  /// The server's limit.
  static const _maxChars = 300;
  final _field = TextEditingController();
  OwnCard? _own;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _writeOwn() async {
    final own =
        await showOwnCardSheet(context, game: GameKind.truth, initial: _own);
    if (own != null && mounted) setState(() => _own = own);
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.row),
      borderSide: const BorderSide(color: AppColors.hairline),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const GameIcon(game: GameKind.truth, size: 30),
                const SizedBox(width: 10),
                Text(GameKind.truth.title, style: AppText.title3),
              ],
            ),
            const SizedBox(height: 12),
            Text(_own?.text ?? widget.question, style: AppText.body),
            if (widget.canWriteOwn)
              Align(
                alignment: Alignment.centerLeft,
                child: TextActionButton(
                  label: _own == null
                      ? 'Ask your own question'
                      : 'Edit your question',
                  onPressed: _writeOwn,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _field,
              autofocus: !widget.canWriteOwn,
              maxLength: _maxChars,
              maxLines: 5,
              minLines: 2,
              style: AppText.body,
              cursorColor: AppColors.accent,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Your answer',
                hintStyle: AppText.body.copyWith(color: AppColors.label3),
                filled: true,
                fillColor: AppColors.menu,
                contentPadding: const EdgeInsets.all(12),
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Send',
              onPressed: _field.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop((_own, _field.text.trim())),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the starter decides about the film they were dealt.
enum MovieChoice { send, another, own }

/// Guess the movie, for the starter: the clue and the film it is, to send or
/// swap for another. Null if they back out.
Future<MovieChoice?> showMovieDealSheet(
  BuildContext context, {
  required GameCard card,
}) {
  return showAppSheet<MovieChoice>(
    context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const GameIcon(game: GameKind.guessMovie, size: 30),
            const SizedBox(width: 10),
            Text(GameKind.guessMovie.title, style: AppText.title3),
          ],
        ),
        const SizedBox(height: 16),
        Text(card.text, textAlign: TextAlign.center, style: AppText.largeTitle),
        const SizedBox(height: 8),
        Text(
          card.options.isEmpty ? '' : card.options.first,
          textAlign: TextAlign.center,
          style: AppText.bodyStrong,
        ),
        const SizedBox(height: 4),
        Text(
          'They see the emoji and four films to pick from.',
          textAlign: TextAlign.center,
          style: AppText.footnote.copyWith(color: AppColors.label2),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Send',
          onPressed: () => Navigator.of(sheetContext).pop(MovieChoice.send),
        ),
        const SizedBox(height: 8),
        SecondaryButton(
          label: 'Another film',
          onPressed: () => Navigator.of(sheetContext).pop(MovieChoice.another),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextActionButton(
            label: 'Send your own film',
            onPressed: () => Navigator.of(sheetContext).pop(MovieChoice.own),
          ),
        ),
      ],
    ),
  );
}

// Your own cards.

/// A text box as the game sheets draw them.
class _GameField extends StatelessWidget {
  const _GameField({
    required this.controller,
    required this.hint,
    required this.maxChars,
    this.onChanged,
    this.autofocus = false,
    this.multiline = false,
    this.capitals = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;
  final int maxChars;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool multiline;
  final TextCapitalization capitals;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.row),
      borderSide: const BorderSide(color: AppColors.hairline),
    );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: maxChars,
      maxLines: multiline ? 3 : 1,
      minLines: 1,
      textCapitalization: capitals,
      style: AppText.body,
      cursorColor: AppColors.accent,
      onChanged: onChanged,
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: AppText.body.copyWith(color: AppColors.label3),
        filled: true,
        fillColor: AppColors.menu,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}

/// A card of your own for [game], in place of one dealt: a question and two
/// answers, a never have I ever line, two sides of a rapid fire card, a truth
/// question, or a film and its emoji. Null if they back out. The server checks
/// it as it checks a message.
Future<OwnCard?> showOwnCardSheet(
  BuildContext context, {
  required GameKind game,
  OwnCard? initial,
}) {
  return showAppSheet<OwnCard>(
    context,
    builder: (_) => _OwnCard(game: game, initial: initial),
  );
}

class _OwnCard extends StatefulWidget {
  const _OwnCard({required this.game, this.initial});

  final GameKind game;
  final OwnCard? initial;

  @override
  State<_OwnCard> createState() => _OwnCardState();
}

class _OwnCardState extends State<_OwnCard> {
  /// The server's limits.
  static const _question = 140;
  static const _option = 40;
  static const _clue = 40;
  static const _title = 80;

  late final _text = TextEditingController(text: widget.initial?.text);
  late final _first = TextEditingController(
    text: widget.initial?.options.elementAtOrNull(0),
  );
  late final _second = TextEditingController(
    text: widget.initial?.options.elementAtOrNull(1),
  );

  @override
  void dispose() {
    _text.dispose();
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  String get _t => _text.text.trim();
  String get _a => _first.text.trim();
  String get _b => _second.text.trim();

  bool get _twoAnswers =>
      _a.isNotEmpty && _b.isNotEmpty && _a.toLowerCase() != _b.toLowerCase();

  OwnCard? get _card => switch (widget.game) {
        GameKind.wouldYouRather when _t.isNotEmpty && _twoAnswers =>
          OwnCard(text: _t, options: [_a, _b]),
        GameKind.neverHaveIEver when _t.isNotEmpty => OwnCard(text: _t),
        GameKind.rapidFire when _twoAnswers => OwnCard(options: [_a, _b]),
        GameKind.truth when _t.isNotEmpty => OwnCard(text: _t),
        GameKind.guessMovie when _t.isNotEmpty && _a.isNotEmpty =>
          OwnCard(text: _t, options: [_a]),
        _ => null,
      };

  (String, List<Widget>) get _form {
    void changed(String _) => setState(() {});
    switch (widget.game) {
      case GameKind.wouldYouRather:
        return (
          'Ask your own question, with the two answers to pick from.',
          [
            _GameField(
              controller: _text,
              hint: 'Your question',
              maxChars: _question,
              multiline: true,
              autofocus: true,
              onChanged: changed,
            ),
            _GameField(
              controller: _first,
              hint: 'One answer',
              maxChars: _option,
              onChanged: changed,
            ),
            _GameField(
              controller: _second,
              hint: 'The other answer',
              maxChars: _option,
              onChanged: changed,
            ),
          ],
        );
      case GameKind.neverHaveIEver:
        return (
          'Finish the line. You both say whether you have.',
          [
            Text('Never have I ever…', style: AppText.bodyStrong),
            _GameField(
              controller: _text,
              hint: 'been on a night safari',
              maxChars: _question,
              multiline: true,
              autofocus: true,
              capitals: TextCapitalization.none,
              onChanged: changed,
            ),
          ],
        );
      case GameKind.rapidFire:
        return (
          'Two quick choices. You both pick one.',
          [
            _GameField(
              controller: _first,
              hint: 'This',
              maxChars: _option,
              autofocus: true,
              onChanged: changed,
            ),
            Text('or', textAlign: TextAlign.center, style: AppText.footnote),
            _GameField(
              controller: _second,
              hint: 'That',
              maxChars: _option,
              onChanged: changed,
            ),
          ],
        );
      case GameKind.truth:
        return (
          'Ask anything warm and curious. You both answer it.',
          [
            _GameField(
              controller: _text,
              hint: 'Your question',
              maxChars: _question,
              multiline: true,
              autofocus: true,
              onChanged: changed,
            ),
          ],
        );
      case GameKind.guessMovie:
        return (
          'Spell out any film in emoji. They type its name to guess.',
          [
            _GameField(
              controller: _text,
              hint: 'Emoji clue, like 🦁👑🌅',
              maxChars: _clue,
              autofocus: true,
              capitals: TextCapitalization.none,
              onChanged: changed,
            ),
            _GameField(
              controller: _first,
              hint: 'The film’s name',
              maxChars: _title,
              capitals: TextCapitalization.words,
              onChanged: changed,
            ),
          ],
        );
      case GameKind.twoTruths:
      case GameKind.flames:
      case GameKind.ticTacToe:
      case GameKind.worduel:
        return ('', const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (help, fields) = _form;
    final card = _card;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GameIcon(game: widget.game, size: 30),
                const SizedBox(width: 10),
                Text('Write your own', style: AppText.title3),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              help,
              style: AppText.footnote.copyWith(color: AppColors.label2),
            ),
            const SizedBox(height: 14),
            for (final field in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: field,
              ),
            const SizedBox(height: 4),
            PrimaryButton(
              label: 'Use this',
              onPressed:
                  card == null ? null : () => Navigator.of(context).pop(card),
            ),
          ],
        ),
      ),
    );
  }
}

// Worduel.

/// Worduel, for the setter: one of the words dealt, or their own. Returns the
/// word's key or an [OwnCard] holding their word. Null if they back out.
Future<Object?> showWorduelStartSheet(
  BuildContext context, {
  required List<GameCard> words,
}) {
  return showAppSheet<Object>(
    context,
    builder: (_) => _WorduelStart(words: words),
  );
}

class _WorduelStart extends StatefulWidget {
  const _WorduelStart({required this.words});

  final List<GameCard> words;

  @override
  State<_WorduelStart> createState() => _WorduelStartState();
}

class _WorduelStartState extends State<_WorduelStart> {
  final _own = TextEditingController();

  /// The word picked from those dealt, by key. Writing your own clears it.
  String? _picked;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  String get _word => _own.text.trim().toLowerCase();
  bool get _ownReady => worduelWordReady(_word);

  @override
  Widget build(BuildContext context) {
    final ready = _picked != null || _ownReady;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const GameIcon(game: GameKind.worduel, size: 30),
                const SizedBox(width: 10),
                Text(GameKind.worduel.title, style: AppText.title3),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a word for them to guess, or set your own. They get '
              '${Worduel.tries} tries, and see which letters are right.',
              style: AppText.footnote.copyWith(color: AppColors.label2),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < widget.words.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: ChoicePill(
                      label: widget.words[i].text.toUpperCase(),
                      lit: _picked == widget.words[i].key,
                      onTap: () => setState(() {
                        _picked = widget.words[i].key;
                        _own.clear();
                      }),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Or your own: any real word, English or Hinglish',
              style: AppText.footnote,
            ),
            const SizedBox(height: 6),
            _GameField(
              controller: _own,
              hint: 'Five letters',
              maxChars: Worduel.letters,
              capitals: TextCapitalization.characters,
              onChanged: (_) => setState(() {
                if (_own.text.isNotEmpty) _picked = null;
              }),
            ),
            if (_word.isNotEmpty && !_ownReady)
              Text(
                'Use ${Worduel.letters} letters, A to Z.',
                style: AppText.micro.copyWith(color: AppColors.label2),
              ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Send',
              onPressed: !ready
                  ? null
                  : () => Navigator.of(context).pop(
                        _picked ?? OwnCard(text: _word),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether [word] can be set or guessed: five letters, a to z.
bool worduelWordReady(String word) =>
    word.length == Worduel.letters && RegExp(r'^[a-z]+$').hasMatch(word);

/// A Worduel's guesses as rows of letter tiles, with an empty row for each
/// try left. A letter in the right place is green; one in the word but
/// elsewhere is yellow; one not in it is grey.
class WorduelGrid extends StatelessWidget {
  const WorduelGrid({required this.guesses, this.showEmpty = true, super.key});

  final List<WorduelGuess> guesses;
  final bool showEmpty;

  static const _tile = 38.0;

  @override
  Widget build(BuildContext context) {
    final rows = showEmpty ? Worduel.tries : guesses.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < Worduel.letters; c++) ...[
                  if (c > 0) const SizedBox(width: 4),
                  r < guesses.length ? _letter(guesses[r], c) : _empty(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _empty() => Container(
        width: _tile,
        height: _tile,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: AppColors.hairline),
        ),
      );

  Widget _letter(WorduelGuess guess, int i) {
    final letter = i < guess.word.length ? guess.word[i].toUpperCase() : '';
    final mark = i < guess.marks.length ? guess.marks[i] : 'a';
    final (bg, said) = switch (mark) {
      'c' => (AppColors.letterRight, 'right place'),
      'p' => (AppColors.letterElsewhere, 'in the word'),
      _ => (AppColors.letterAbsent, 'not in it'),
    };
    return Semantics(
      label: '$letter, $said',
      excludeSemantics: true,
      child: Container(
        width: _tile,
        height: _tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          letter,
          style: AppText.bodyStrong.copyWith(color: AppColors.onAccent),
        ),
      ),
    );
  }
}

/// Tic tac toe, before it starts: tap the square for your first x.
Future<int?> showBoardStartSheet(BuildContext context) {
  return showAppSheet<int>(
    context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const GameIcon(game: GameKind.ticTacToe, size: 30),
            const SizedBox(width: 10),
            Text(GameKind.ticTacToe.title, style: AppText.title3),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'You are X. Tap a square to make the first move.',
          style: AppText.footnote.copyWith(color: AppColors.label2),
        ),
        const SizedBox(height: 14),
        Center(
          child: TicTacToeBoard(
            board: '         ',
            onTap: (cell) => Navigator.of(sheetContext).pop(cell),
          ),
        ),
      ],
    ),
  );
}

/// A tic tac toe board. [onTap] is called for an empty square, and only when
/// set: on your turn. [line] lights the three that won.
class TicTacToeBoard extends StatelessWidget {
  const TicTacToeBoard({
    required this.board,
    this.onTap,
    this.line,
    this.size = 216,
    super.key,
  });

  final String board;
  final ValueChanged<int>? onTap;
  final List<int>? line;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cell = (size - 8) / 3;
    return SizedBox(
      width: size,
      height: size,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < 9; i++) _square(i, cell),
        ],
      ),
    );
  }

  Widget _square(int i, double side) {
    final mark = i < board.length ? board[i] : ' ';
    final lit = line?.contains(i) ?? false;
    final open = mark == ' ' && onTap != null;
    return Pressable(
      onTap: open ? () => onTap!(i) : null,
      semanticLabel: mark == ' '
          ? 'Empty square ${i + 1}'
          : '${mark.toUpperCase()} on square ${i + 1}',
      child: Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lit ? AppColors.fill : AppColors.fill2,
          borderRadius: BorderRadius.circular(Radii.row),
          border:
              Border.all(color: open ? AppColors.accent : AppColors.hairline),
        ),
        child: Text(
          mark == ' ' ? '' : mark.toUpperCase(),
          style: AppText.title1.copyWith(
            color: lit
                ? AppColors.onAccent
                : mark == 'x'
                    ? AppColors.accent
                    : AppColors.label,
          ),
        ),
      ),
    );
  }
}
