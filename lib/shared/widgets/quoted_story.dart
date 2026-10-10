import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../models/chat.dart';
import '../models/enums.dart';
import '../models/tile_look.dart';

/// An in common story a message replies to, above the message the way a
/// quoted tile is: in the story's own colours, with its eyebrow and claim.
class QuotedStory extends StatelessWidget {
  const QuotedStory({required this.story, super.key});

  final StoryQuote story;

  /// The colours a story wears: its category's tile gradient, or the brand's
  /// for the thought and a difference between two categories.
  static LinearGradient gradientFor(TileCategory? category, String? kind) {
    if (category != null && category != TileCategory.unknown) {
      return TileTones.of(category.tone);
    }
    return kind == 'thought' ? TileTones.rose : AppColors.promo;
  }

  @override
  Widget build(BuildContext context) {
    if (story.removed) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.fill2,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: AppColors.tileEdge, width: 0.67),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hide_source, size: 16, color: AppColors.label3),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'This story is no longer shared.',
                style: AppText.footnote.copyWith(color: AppColors.label3),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: gradientFor(story.category, story.kind),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.tileEdge, width: 0.67),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '✨ IN COMMON',
            style: AppText.micro.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.label2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            story.title ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyStrong.copyWith(color: AppColors.label),
          ),
        ],
      ),
    );
  }
}
