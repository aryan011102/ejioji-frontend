import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// A numbered step in a run of them.
///
/// The rule is drawn *behind* the numerals rather than between cards, so three
/// steps read as one process rather than three separate things to do.
class StepRow extends StatelessWidget {
  const StepRow({
    required this.number,
    required this.title,
    required this.body,
    this.last = false,
    super.key,
  });

  final String number;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 31,
            child: Column(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: const BoxDecoration(
                    color: AppColors.fill2,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number,
                    style: AppText.bodyStrong.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!last)
                  const Expanded(
                    child: VerticalDivider(
                      width: 1.5,
                      thickness: 1.5,
                      color: AppColors.separator,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 0, last ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.title3.copyWith(fontSize: 16.5)),
                  const SizedBox(height: 3),
                  Text(body, style: AppText.footnote.copyWith(fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The big mark on a result screen.
///
/// Done is a filled circle, pending is the check still thinking, failed is
/// never red — a failed check is almost always a bad photo rather than a bad
/// person, and colouring it like an error says otherwise.
class ResultMark extends StatelessWidget {
  const ResultMark({
    required this.icon,
    this.filled = false,
    this.color = AppColors.blue,
    this.size = 88,
    super.key,
  });

  final IconData icon;
  final bool filled;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : AppColors.fill2,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.46,
        color: filled ? AppColors.onAccent : AppColors.label2,
      ),
    );
  }
}

/// A centred outcome screen: mark, headline, a paragraph, and up to two ways
/// forward. Every result in the product uses it, so they all feel like the
/// same moment.
class ResultScaffoldBody extends StatelessWidget {
  const ResultScaffoldBody({
    required this.mark,
    required this.title,
    required this.body,
    this.note,
    super.key,
  });

  final Widget mark;
  final String title;
  final String body;
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark,
            const SizedBox(height: 26),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title1.copyWith(fontSize: 27, height: 33 / 27),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.callout.copyWith(fontSize: 15.5, height: 22 / 15.5),
            ),
            if (note != null) ...[const SizedBox(height: 24), note!],
          ],
        ),
      ),
    );
  }
}
