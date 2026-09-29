import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../models/enums.dart';
import 'pressable.dart';

/// One chip in the row of facts under a name.
class Fact {
  const Fact(this.glyph, this.label, {this.mark, this.onTap});

  final String glyph;
  final String label;
  final Widget? mark;
  final VoidCallback? onTap;
}

/// The facts under a name, in the order the design draws them.
///
/// Languages collapse to "Hindi, English +1" rather than wrapping: the row
/// scrolls, so a long list would push the rest out of reach. Anything the
/// person has not stated is left out entirely instead of showing an empty
/// chip, which is the same rule as pronouns.
List<Fact> profileFacts({
  required int age,
  required City city,
  required List<Language> languages,
  required Education? education,
  required String? company,
  required Habit? smoking,
  required Habit? drinking,
}) {
  return [
    Fact('📍', city.label),
    Fact('🎂', '$age'),
    if (company != null && company.isNotEmpty) Fact('💼', company),
    if (languages.isNotEmpty)
      Fact(
        '🗣',
        languages.length <= 2
            ? [for (final l in languages) l.label].join(', ')
            : '${languages[0].label}, ${languages[1].label} '
                '+${languages.length - 2}',
      ),
    if (education != null) Fact('💻', education.label),
    if (smoking != null) Fact('🚬', smoking.smokingLabel),
    if (drinking != null) Fact('🍷', drinking.drinkingLabel),
  ];
}

/// The chips in one row that scrolls sideways.
///
/// Meant to be laid edge to edge, so a chip scrolls off the screen (or the
/// card) rather than being cut at the gutter; [padding] is the gutter.
class FactChipRow extends StatelessWidget {
  const FactChipRow({
    super.key,
    required this.facts,
    this.padding = const EdgeInsets.symmetric(horizontal: Insets.gutter),
  });

  final List<Fact> facts;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: facts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) => FactChip(fact: facts[i]),
      ),
    );
  }
}

class FactChip extends StatelessWidget {
  const FactChip({super.key, required this.fact});

  final Fact fact;

  @override
  Widget build(BuildContext context) {
    // The design's pill: the quiet system fill, not the brand plum, 34 high.
    final chip = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: AppColors.fill2,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          fact.mark ??
              Text(
                fact.glyph,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
          const SizedBox(width: 6),
          Text(
            fact.label,
            style: AppText.body.copyWith(
              fontSize: 14,
              height: 21 / 14,
              letterSpacing: 0,
              color: AppColors.label,
            ),
          ),
        ],
      ),
    );
    final onTap = fact.onTap;
    if (onTap == null) return chip;
    return Pressable(onTap: onTap, semanticLabel: fact.label, child: chip);
  }
}
