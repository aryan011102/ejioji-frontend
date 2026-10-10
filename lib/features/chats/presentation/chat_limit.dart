import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

/// Open chats a person can have at once (Aryan's call, 2026-10-10): the same as
/// the requests they get a day. The server's `chat_open_max` is the rule; this is
/// only the number the popup says.
const openChatsMax = 8;

/// A match past the open chats is listed but does not open (the server answers
/// 409 `chat_limit`). Tapping one says why, and what to do about it, and nothing
/// else: no list to pick from, so the choice of whom to unmatch is made inside
/// that chat, where the person is in front of them.
Future<void> showChatLimitSheet(BuildContext context, {String? name}) {
  return showAppSheet<void>(
    context,
    builder: (context) => ChatLimitCard(
      name: name,
      onDone: () => Navigator.of(context).pop(),
    ),
  );
}

class ChatLimitCard extends StatelessWidget {
  const ChatLimitCard({required this.onDone, this.name, super.key});

  /// Who is waiting, when it is known.
  final String? name;
  final VoidCallback onDone;

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
            Icons.forum_outlined,
            size: 44,
            radius: 13,
            background: AppColors.fill2,
            foreground: AppColors.label,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'You already have $openChatsMax open chats',
          style: AppText.title3,
        ),
        const SizedBox(height: 8),
        Text(
          who == null
              ? 'To chat with someone new, unmatch one of them first.'
              : 'To chat with $who, unmatch one of them first.',
          style: AppText.callout,
        ),
        const SizedBox(height: 8),
        Text(
          'Open a chat and tap ··· to unmatch.',
          style: AppText.caption,
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Got it', onPressed: onDone),
      ],
    );
  }
}
