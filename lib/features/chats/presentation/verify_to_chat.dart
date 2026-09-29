import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

/// Writing in a chat needs a verified profile. Asking, accepting and reading do
/// not, so this is met on a conversation that is already open: the person can
/// read what was written to them and cannot answer until they verify.
///
/// The server decides (`verification_required` on a page of messages, or 403
/// `verification_required` on a send). The app only says so.

/// The popup, shown once when such a chat opens, and again if a send is
/// refused. Returns true if they chose to verify now.
Future<bool> showVerifyToChatSheet(BuildContext context, {String? name}) async {
  final chosen = await showAppSheet<bool>(
    context,
    builder: (context) => VerifyToChatCard(
      name: name,
      onVerify: () => Navigator.of(context).pop(true),
      onLater: () => Navigator.of(context).pop(false),
    ),
  );
  return chosen ?? false;
}

class VerifyToChatCard extends StatelessWidget {
  const VerifyToChatCard({
    required this.onVerify,
    required this.onLater,
    this.name,
    super.key,
  });

  /// The other person's first name, when it is known.
  final String? name;
  final VoidCallback onVerify;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final who = name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: IconPlate(
            Icons.verified_outlined,
            size: 44,
            radius: 13,
            background: AppColors.blueSoft,
            foreground: AppColors.blue,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          who == null ? 'Verify to start chatting' : 'Verify to chat with $who',
          style: AppText.title3,
        ),
        const SizedBox(height: 8),
        Text(
          'Only verified people can send messages on theonebytwo. You can '
          'still read what is written to you.',
          style: AppText.callout,
        ),
        const SizedBox(height: 8),
        Text(
          'DigiLocker checks your name and date of birth against Aadhaar. It '
          'takes about a minute.',
          style: AppText.caption,
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Verify now', onPressed: onVerify),
        const SizedBox(height: 4),
        Center(
          child: TextActionButton(label: 'Not now', dim: true, onPressed: onLater),
        ),
      ],
    );
  }
}

/// In place of the keyboard, while the person cannot write here.
class VerifyToChatBar extends StatelessWidget {
  const VerifyToChatBar({required this.onVerify, super.key});

  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Verify your profile to send messages.',
              style: AppText.caption,
            ),
          ),
          const SizedBox(width: 12),
          MiniButton(label: 'Verify', onPressed: onVerify),
        ],
      ),
    );
  }
}
