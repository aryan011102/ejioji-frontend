import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/models/game.dart';
import '../../../../shared/widgets/buttons.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../../shared/widgets/sheets.dart';

/// The games, like the apps row in iMessage: tap one to play it in this chat.
/// Frosted glass over the chat, one row a game: its mark and its name.
Future<GameKind?> showGamesSheet(BuildContext context) {
  return _showGlassSheet<GameKind>(
    context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Play a game', style: AppText.bodyStrong),
        const SizedBox(height: 10),
        for (final game in GameKind.values.where((g) => g.offered))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Pressable(
              onTap: () => Navigator.of(sheetContext).pop(game),
              semanticLabel: game.title,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.liquidSheen,
                  borderRadius: BorderRadius.circular(Radii.row),
                  border: Border.all(color: AppColors.glassEdge),
                ),
                child: Row(
                  children: [
                    GameIcon(game: game, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(game.title, style: AppText.body),
                    ),
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

  IconData get _icon => iconFor(game);

  /// The bare mark, for the small line at the top of a game card.
  static IconData iconFor(GameKind? game) => switch (game) {
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
    this.showText = true,
    this.compact = false,
    super.key,
  });

  final GameCard card;
  final int? picked;
  final ValueChanged<int>? onPick;

  /// False where the two answers already say it: rapid fire's "A or B?".
  final bool showText;

  /// On a card in the chat: smaller words, closer together.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showText) ...[
          Text(
            card.text,
            style: compact
                ? AppText.callout.copyWith(color: AppColors.label)
                : AppText.body,
          ),
          SizedBox(height: compact ? 6 : 8),
        ],
        Row(
          children: [
            for (var o = 0; o < card.options.length; o++) ...[
              if (o > 0) SizedBox(width: compact ? 6 : 8),
              Expanded(
                child: ChoicePill(
                  label: card.options[o],
                  lit: picked == o,
                  compact: compact,
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
    this.compact = false,
    super.key,
  });

  final String label;
  final bool lit;
  final VoidCallback? onTap;

  /// On a card in the chat: a smaller word on a lower pill.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 8 : 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lit ? AppColors.fill : AppColors.fill2,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: lit ? AppColors.fill : AppColors.hairline),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: (compact ? AppText.footnote : AppText.callout).copyWith(
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
/// out. Truth is no longer started (GameKind.offered); this answers one sent
/// before.
Future<String?> showTruthSheet(
  BuildContext context, {
  required String question,
}) {
  return showAppSheet<String>(
    context,
    builder: (_) => _TruthAnswer(question: question),
  );
}

class _TruthAnswer extends StatefulWidget {
  const _TruthAnswer({required this.question});

  final String question;

  @override
  State<_TruthAnswer> createState() => _TruthAnswerState();
}

class _TruthAnswerState extends State<_TruthAnswer> {
  /// The server's limit.
  static const _maxChars = 300;
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
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
            Text(widget.question, style: AppText.body),
            const SizedBox(height: 12),
            TextField(
              controller: _field,
              autofocus: true,
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
                  : () => Navigator.of(context).pop(_field.text.trim()),
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
      case GameKind.truth:
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

/// Worduel, for the setter: the word is the tiles. Type one, any real word in
/// English or Hinglish, or tap a suggestion to fill them; [more] deals other
/// suggestions. Returns the suggestion's key, or an [OwnCard] holding a typed
/// word. Null if they back out.
Future<Object?> showWorduelStartSheet(
  BuildContext context, {
  required List<GameCard> words,
  required String theirName,
  Future<List<GameCard>> Function()? more,
}) {
  return showAppSheet<Object>(
    context,
    builder: (_) =>
        _WorduelStart(words: words, theirName: theirName, more: more),
  );
}

class _WorduelStart extends StatefulWidget {
  const _WorduelStart({
    required this.words,
    required this.theirName,
    this.more,
  });

  final List<GameCard> words;
  final String theirName;
  final Future<List<GameCard>> Function()? more;

  @override
  State<_WorduelStart> createState() => _WorduelStartState();
}

class _WorduelStartState extends State<_WorduelStart> {
  final _typed = TextEditingController();
  late List<GameCard> _words = widget.words;
  bool _dealing = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  String get _word => _typed.text.trim().toLowerCase();

  /// The suggestion the tiles hold, if they hold one exactly.
  GameCard? get _suggested =>
      _words.where((w) => w.text.toLowerCase() == _word).firstOrNull;

  void _fill(GameCard word) {
    final text = word.text.toUpperCase();
    _typed.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  Future<void> _dealMore() async {
    final more = widget.more;
    if (more == null || _dealing) return;
    setState(() => _dealing = true);
    try {
      final words = await more();
      if (mounted && words.isNotEmpty) setState(() => _words = words);
    } finally {
      if (mounted) setState(() => _dealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = worduelWordReady(_word);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set a word for ${widget.theirName}',
              textAlign: TextAlign.center,
              style: AppText.bodyStrong,
            ),
            const SizedBox(height: 14),
            Center(
              child: Stack(
                children: [
                  WorduelGrid(
                    guesses: const [],
                    showEmpty: false,
                    typing: _word,
                    tile: 44,
                  ),
                  // The keyboard's field, unseen: what is typed shows in the
                  // tiles.
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _typed,
                        autofocus: true,
                        maxLength: Worduel.letters,
                        autocorrect: false,
                        enableSuggestions: false,
                        showCursor: false,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                Text('or', style: AppText.caption),
                for (final w in _words)
                  Pressable(
                    onTap: () => _fill(w),
                    semanticLabel: 'Use ${w.text}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _suggested == w
                            ? AppColors.fill
                            : AppColors.fill2,
                        borderRadius: BorderRadius.circular(Radii.chip),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Text(
                        w.text.toUpperCase(),
                        style: AppText.footnote.copyWith(
                          color: _suggested == w
                              ? AppColors.onAccent
                              : AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                if (widget.more != null)
                  Pressable(
                    onTap: _dealing ? null : _dealMore,
                    semanticLabel: 'Other words',
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: AppColors.label2,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Send',
              onPressed: !ready
                  ? null
                  : () => Navigator.of(context).pop(
                        _suggested?.key ?? OwnCard(text: _word),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Worduel row as colour squares only, no letters: a guess as it reads in a
/// shared result.
class WorduelMarks extends StatelessWidget {
  const WorduelMarks({required this.marks, this.size = 11, super.key});

  final String marks;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < marks.length; i++) ...[
          if (i > 0) SizedBox(width: size * 0.2),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: switch (marks[i]) {
                'c' => AppColors.letterRight,
                'p' => AppColors.letterElsewhere,
                _ => AppColors.letterAbsent,
              },
              borderRadius: BorderRadius.circular(size * 0.2),
            ),
          ),
        ],
      ],
    );
  }
}

/// Every guess of a Worduel as colour squares, oldest first: how close they
/// got, without the letters.
class WorduelPath extends StatelessWidget {
  const WorduelPath({required this.guesses, this.size = 11, super.key});

  final List<WorduelGuess> guesses;
  final double size;

  @override
  Widget build(BuildContext context) {
    final right = [
      for (final g in guesses) 'c'.allMatches(g.marks).length,
    ];
    return Semantics(
      label: [
        for (var i = 0; i < guesses.length; i++)
          'Guess ${i + 1}: ${right[i]} in the right place',
      ].join('. '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < guesses.length; i++) ...[
            if (i > 0) SizedBox(height: size * 0.2),
            WorduelMarks(marks: guesses[i].marks, size: size),
          ],
        ],
      ),
    );
  }
}

/// A word in letter tiles, all one colour: the setter's word, or the answer.
class WorduelWord extends StatelessWidget {
  const WorduelWord({
    required this.word,
    this.tile = 18,
    this.color = AppColors.letterAbsent,
    this.flipped = 1,
    super.key,
  });

  final String word;
  final double tile;
  final Color color;

  /// How far a reveal has got, 0 to 1: the tiles flip over one at a time,
  /// turning [color] as each passes edge on. 1 draws them all turned.
  final double flipped;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'The word: ${word.toUpperCase()}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < word.length; i++) ...[
            if (i > 0) SizedBox(width: tile * 0.15),
            _tile(i, ((flipped - i * 0.13) / 0.3).clamp(0.0, 1.0)),
          ],
        ],
      ),
    );
  }

  Widget _tile(int i, double flip) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateX(math.sin(flip * math.pi) * math.pi / 2),
        child: Container(
          width: tile,
          height: tile,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: flip >= 0.5 ? color : AppColors.letterAbsent,
            borderRadius: BorderRadius.circular(tile * 0.2),
          ),
          child: Text(
            word[i].toUpperCase(),
            style: AppText.bodyStrong.copyWith(
              color: AppColors.onAccent,
              fontSize: tile * 0.5,
              height: 1,
            ),
          ),
        ),
      );
}

/// Whether [word] can be set or guessed: five letters, a to z.
bool worduelWordReady(String word) =>
    word.length == Worduel.letters && RegExp(r'^[a-z]+$').hasMatch(word);

/// A Worduel's guesses as rows of letter tiles. A letter in the right place is
/// green; one in the word but elsewhere is yellow; one not in it is grey.
///
/// [typing] adds the row being typed, its letters so far outlined. With
/// [showEmpty], an empty row stands for each try left; on a card in the chat
/// only the rows played show, so a new game is one row, not six.
class WorduelGrid extends StatelessWidget {
  const WorduelGrid({
    required this.guesses,
    this.showEmpty = true,
    this.typing,
    this.tile = 38,
    super.key,
  });

  final List<WorduelGuess> guesses;
  final bool showEmpty;
  final String? typing;
  final double tile;

  double get _radius => tile * 0.2;

  @override
  Widget build(BuildContext context) {
    final played = guesses.length;
    final rows = showEmpty
        ? Worduel.tries
        : played + (typing != null && played < Worduel.tries ? 1 : 0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < Worduel.letters; c++) ...[
                  if (c > 0) const SizedBox(width: 4),
                  if (r < played)
                    _letter(guesses[r], c)
                  else if (r == played && typing != null)
                    _typed(c < typing!.length ? typing![c] : null)
                  else
                    _empty(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _empty() => Container(
        width: tile,
        height: tile,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: AppColors.hairline),
        ),
      );

  Widget _typed(String? letter) => Container(
        width: tile,
        height: tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: letter == null ? AppColors.label4 : AppColors.accent,
          ),
        ),
        child: Text(
          letter?.toUpperCase() ?? '',
          style: AppText.bodyStrong.copyWith(color: AppColors.label),
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
        width: tile,
        height: tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_radius),
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
/// set: on your turn. [line] lights the three that won, with a stroke across
/// them drawn as far as [drawn] (0 to 1) says.
class TicTacToeBoard extends StatelessWidget {
  const TicTacToeBoard({
    required this.board,
    this.onTap,
    this.line,
    this.drawn = 1,
    this.size = 216,
    super.key,
  });

  final String board;
  final ValueChanged<int>? onTap;
  final List<int>? line;
  final double drawn;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cell = (size - 8) / 3;
    final won = line;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        foregroundPainter: won == null || won.length < 3 || drawn <= 0
            ? null
            : _LinePainter(won.first, won.last, cell, drawn),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < 9; i++) _square(i, cell),
          ],
        ),
      ),
    );
  }

  Widget _square(int i, double side) {
    final mark = i < board.length ? board[i] : ' ';
    // The winning squares light once the stroke has crossed them.
    final lit = (line?.contains(i) ?? false) && drawn >= 1;
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
          borderRadius: BorderRadius.circular(size < 180 ? 8 : Radii.row),
          border:
              Border.all(color: open ? AppColors.accent : AppColors.hairline),
        ),
        child: Text(
          mark == ' ' ? '' : mark.toUpperCase(),
          style: (size < 180 ? AppText.title3 : AppText.title1).copyWith(
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

/// The stroke through a winning line, from the centre of its first square to
/// its last, drawn [drawn] of the way.
class _LinePainter extends CustomPainter {
  _LinePainter(this.from, this.to, this.cell, this.drawn);

  final int from;
  final int to;
  final double cell;
  final double drawn;

  Offset _centre(int i) =>
      Offset((i % 3) * (cell + 4) + cell / 2, (i ~/ 3) * (cell + 4) + cell / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final a = _centre(from);
    final b = _centre(to);
    canvas.drawLine(
      a,
      Offset.lerp(a, b, drawn)!,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.drawn != drawn || old.from != from || old.to != to;
}

/// A finished game, opened from its line in the chat: frosted glass over the
/// conversation, as the tab bar is, so it reads as a look at the result rather
/// than a new screen. Swipe down to go back.
Future<void> showGameResultSheet(
  BuildContext context, {
  required Widget child,
}) {
  return _showGlassSheet<void>(context, builder: (_) => child);
}

/// A sheet of frosted glass over the chat, for the games only: the list of
/// games and a finished game's result. Every other sheet in the app is solid
/// (showAppSheet), and stays so until glass is decided for all of them.
Future<T?> _showGlassSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: const Color(0x00000000),
    barrierColor: AppColors.scrimLight,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.card),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: AppColors.glassEdge),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.label4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
                      ),
                      child: SingleChildScrollView(
                        child: builder(sheetContext),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
