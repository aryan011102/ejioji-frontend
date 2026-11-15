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

/// Your picks on the cards you were dealt, one per card, in order. Null if they
/// back out.
Future<List<int>?> showCardsSheet(
  BuildContext context, {
  required GameKind game,
  required List<GameCard> cards,
}) {
  return showAppSheet<List<int>>(
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

  @override
  Widget build(BuildContext context) {
    final ready = _picks.every((p) => p != null);
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
                  for (var i = 0; i < widget.cards.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: CardChoice(
                        card: widget.cards[i],
                        picked: _picks[i],
                        onPick: (p) => setState(() => _picks[i] = p),
                      ),
                    ),
                ],
              ),
            ),
          ),
          PrimaryButton(
            label: 'Send',
            onPressed: ready
                ? () => Navigator.of(context).pop([for (final p in _picks) p!])
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
  const ChoicePill(
      {required this.label, required this.lit, this.onTap, super.key});

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
