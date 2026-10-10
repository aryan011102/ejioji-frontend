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
/// A signpost, as the AI question is: the notice itself is one tap away and is
/// what the grant records.
class InCommonAskCard extends StatelessWidget {
  const InCommonAskCard({
    required this.name,
    required this.themSaidYes,
    required this.onAllow,
    required this.onNotNow,
    required this.onReadNotice,
    super.key,
  });

  final String name;
  final bool themSaidYes;
  final VoidCallback onAllow;
  final VoidCallback onNotNow;
  final VoidCallback onReadNotice;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: IconPlate(
            Icons.join_inner,
            size: 44,
            radius: 13,
            background: AppColors.glow,
            foreground: AppColors.accent,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          themSaidYes
              ? '$name wants to see what you two have in common'
              : 'See what you and $name have in common?',
          style: AppText.title3,
        ),
        const SizedBox(height: 8),
        Text(
          'We pick out the few things you two share, and one way you differ, '
          'from your insights. That includes the ones you kept off your '
          'profile, so the stories can find more than your profile shows.',
          style: AppText.callout,
        ),
        const SizedBox(height: 8),
        Text(
          '$name only ever sees those few things, never the rest, and only once '
          'you have both said yes. Nothing new is collected.',
          style: AppText.caption,
        ),
        const SizedBox(height: 8),
        Text(
          'This is asked once, for all your matches. You can turn it off in '
          'Settings, under Privacy choices.',
          style: AppText.caption,
        ),
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
