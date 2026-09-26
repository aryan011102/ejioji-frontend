import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../models/tile.dart';
import '../models/tile_look.dart';

/// A tile someone asked to chat about, small: on a request, above a message,
/// and at the top of a conversation.
///
/// It wears its category's colour so it reads as the same tile it was on the
/// wall. It is a copy, taken when it was sent, so it says what the tile said
/// then. When what it rested on has gone it shows that it was about a tile
/// and nothing more.
class QuotedTile extends StatelessWidget {
  const QuotedTile({
    required this.tile,
    this.onRemove,
    this.compact = false,
    super.key,
  });

  final TileQuote tile;

  /// Shows a close button. Only on the composer's chip, before sending.
  final VoidCallback? onRemove;

  /// One line of value and caption, for the chip above the keyboard.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (tile.removed) {
      return _frame(
        gradient: null,
        child: Row(
          children: [
            const Icon(Icons.hide_source, size: 16, color: AppColors.label3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This tile is no longer on their profile.',
                style: AppText.footnote.copyWith(color: AppColors.label3),
              ),
            ),
          ],
        ),
      );
    }

    final kicker = tile.isAnswer ? tile.question : null;
    final headline = tile.isAnswer ? tile.answer : tile.displayValue;
    final body = tile.isAnswer ? null : tile.caption;

    return _frame(
      gradient: TileTones.of(tile.category.tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kicker != null) ...[
            Text(
              kicker.toUpperCase(),
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.micro.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: const Color(0xA8FFFFFF),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            headline ?? '',
            maxLines: compact ? 1 : 3,
            overflow: TextOverflow.ellipsis,
            style: tile.isAnswer
                ? AppText.bodyStrong.copyWith(color: AppColors.label)
                : AppText.tileNumber(compact ? 20 : 26),
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              body,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.tileCaption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _frame({required LinearGradient? gradient, required Widget child}) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, onRemove == null ? 12 : 4, 10),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppColors.fill2 : null,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.tileEdge, width: 0.67),
      ),
      child: onRemove == null
          ? child
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: child),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.label,
                  ),
                ),
              ],
            ),
    );
  }
}

/// A line over a quoted tile saying whose it is and who asked: "Riya wants to
/// chat about this", "You asked about this".
class QuotedTileLabel extends StatelessWidget {
  const QuotedTileLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 13,
              color: AppColors.accent,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: AppText.footnote.copyWith(color: AppColors.label2),
              ),
            ),
          ],
        ),
      );
}
