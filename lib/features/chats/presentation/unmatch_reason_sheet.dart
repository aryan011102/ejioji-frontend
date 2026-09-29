import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';

/// Why someone is unmatching, asked as they do it (backend decision log,
/// 2026-09-29). The keys are the server's `UnmatchReason`; the other person is
/// never told, and saying nothing is always an answer.
enum UnmatchReason {
  differentThings('different_things', 'We want different things'),
  noSpark('no_spark', "We didn't click"),
  wentQuiet('went_quiet', 'The conversation went nowhere'),
  metSomeone('met_someone', "I've met someone"),
  notGenuine('not_genuine', "They didn't seem genuine", safety: true),
  disrespectful(
    'disrespectful',
    'They were rude or made me uncomfortable',
    safety: true,
  ),
  other('other', 'Something else');

  const UnmatchReason(this.key, this.label, {this.safety = false});

  /// What the server stores.
  final String key;
  final String label;

  /// Something a moderator should see: the app offers to report instead.
  final bool safety;
}

/// Their answer. [reason] is null when they would rather not say.
@immutable
class UnmatchAnswer {
  const UnmatchAnswer(this.reason);

  final UnmatchReason? reason;
}

/// The question, which is also the confirmation: choosing any answer unmatches,
/// and backing out (the scrim, or Cancel) does not.
Future<UnmatchAnswer?> showUnmatchReasonSheet(
  BuildContext context, {
  required String name,
}) {
  return showAppSheet<UnmatchAnswer>(
    context,
    builder: (sheetContext) => UnmatchReasonCard(
      name: name,
      onAnswer: (answer) => Navigator.of(sheetContext).pop(answer),
      onCancel: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class UnmatchReasonCard extends StatelessWidget {
  const UnmatchReasonCard({
    required this.name,
    required this.onAnswer,
    required this.onCancel,
    super.key,
  });

  final String name;
  final ValueChanged<UnmatchAnswer> onAnswer;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, UnmatchAnswer answer, {bool dim = false}) =>
        Pressable(
          onTap: () => onAnswer(answer),
          child: Container(
            height: 46,
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.separator, width: 0.5),
              ),
            ),
            child: Text(
              label,
              style: AppText.body.copyWith(
                color: dim ? AppColors.label2 : null,
              ),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Why are you unmatching?', style: AppText.title3),
        const SizedBox(height: 6),
        Text(
          'The chat closes for both of you and cannot be reopened. $name is '
          'never told what you pick.',
          style: AppText.caption,
        ),
        const SizedBox(height: 12),
        // Most of the screen at most, so a small phone can still scroll to the
        // last answer and dismiss the sheet.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final reason in UnmatchReason.values)
                row(reason.label, UnmatchAnswer(reason)),
              row('Rather not say', const UnmatchAnswer(null), dim: true),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Pressable(
            onTap: onCancel,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                'Cancel',
                style: AppText.navAction.copyWith(color: AppColors.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
