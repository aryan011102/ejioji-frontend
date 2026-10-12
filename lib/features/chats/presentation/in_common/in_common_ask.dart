import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/buttons.dart';
import '../../../../shared/widgets/layout.dart';

/// The question, put once, the first time someone taps a ring (Aryan,
/// 2026-10-10): may the stories read every insight, not only the ones on the
/// profile. One yes covers every match after it, and nothing is shown to
/// anyone until the other person has said yes too.
///
/// Just the question (Aryan, 2026-10-11): what it reads and who sees what is
/// in the notice, one tap away, which is what the grant records.
class InCommonAskCard extends StatelessWidget {
  const InCommonAskCard({
    required this.name,
    required this.themSaidYes,
    required this.onAllow,
    required this.onNotNow,
    required this.onReadNotice,
    this.opposites = false,
    super.key,
  });

  final String name;
  final bool themSaidYes;
  final VoidCallback onAllow;
  final VoidCallback onNotNow;
  final VoidCallback onReadNotice;

  /// Asking for the opposites deck: two people with too little in common, so
  /// the stories are where they differ (2026-10-12).
  final bool opposites;

  String get _question {
    if (opposites) {
      return themSaidYes
          ? '$name wants to see where you two differ'
          : 'See where you and $name differ?';
    }
    return themSaidYes
        ? '$name wants to see what you two have in common'
        : 'See what you and $name have in common?';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconPlate(
            opposites ? Icons.compare_arrows : Icons.join_inner,
            size: 44,
            radius: 13,
            background: AppColors.glow,
            foreground: AppColors.accent,
          ),
        ),
        const SizedBox(height: 14),
        Text(_question, style: AppText.title3),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextActionButton(
            label: 'Read the full notice',
            onPressed: onReadNotice,
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Show me', onPressed: onAllow),
        const SizedBox(height: 4),
        Center(
          child: TextActionButton(
            label: 'Not now',
            dim: true,
            onPressed: onNotNow,
          ),
        ),
      ],
    );
  }
}

/// Said yes, and the other person has not yet.
class InCommonWaitingCard extends StatelessWidget {
  const InCommonWaitingCard({required this.name, required this.onClose, super.key});

  final String name;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Waiting for $name', style: AppText.title3),
        const SizedBox(height: 8),
        Text(
          'Your stories open once $name says yes too. Nothing of yours is '
          'shown until then.',
          style: AppText.callout,
        ),
        const SizedBox(height: 16),
        SecondaryButton(label: 'OK', onPressed: onClose),
      ],
    );
  }
}
