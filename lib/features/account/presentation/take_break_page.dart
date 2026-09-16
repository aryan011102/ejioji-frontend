import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

/// Three facts, because every worry someone has about pausing is one of these
/// three: you stop appearing, your chats stay, nobody is told.
class TakeBreakPage extends ConsumerWidget {
  const TakeBreakPage({super.key});

  static const _facts = <(IconData, String, String)>[
    (
      Icons.visibility_off_outlined,
      'You stop appearing',
      "Nobody new finds you, and you drop out of everyone's feed and filters.",
    ),
    (
      Icons.chat_bubble_outline,
      'Your chats stay',
      'Conversations, insights and photos are untouched. People you are '
          'already talking to can still reach you.',
    ),
    (
      Icons.nightlight_round,
      'Nobody is told',
      'There is no away message and no notice. You simply stop showing up.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Take a break',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      footer: Column(
        children: [
          PrimaryButton(
            label: 'Hide my profile',
            onPressed: () async {
              final choice = await showAppActionSheet(
                context,
                title: 'Hide your profile?',
                message: "You'll stop appearing to new people straight away. "
                    'Nothing is deleted, and nobody is told.',
                actions: const [SheetAction('Hide my profile')],
              );
              if (choice != 0 || !context.mounted) return;
              try {
                // Taking a break is unpublishing. It does exactly what the
                // three facts on this screen promise: the profile stops being
                // shown, every match and conversation stays, and nobody is
                // told. Publishing again puts it back.
                await ref.read(profileRepositoryProvider).unpublish();
                final profile =
                    await ref.read(profileRepositoryProvider).load();
                if (!context.mounted) return;
                ref.read(sessionProvider.notifier).onProfileChanged(profile);
                context.go(Routes.account);
              } on ApiException catch (e) {
                if (context.mounted) showAppToast(context, e.message);
              }
            },
          ),
          TextActionButton(
            label: 'Delete my account instead',
            destructive: true,
            onPressed: () => context.pop(),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.titleGutter,
              22,
              Insets.titleGutter,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconPlate(
                  Icons.nightlight_round,
                  size: 52,
                  radius: 16,
                ),
                const SizedBox(height: 16),
                Text(
                  'Step away without losing anything.',
                  style: AppText.title2.copyWith(fontSize: 26, height: 32 / 26),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hiding your profile is reversible in one tap. Deleting is '
                  'not.',
                  style: AppText.callout,
                ),
              ],
            ),
          ),
          SectionGroup(
            children: [
              for (final (icon, title, body) in _facts)
                AppRow(
                  label: title,
                  subtitle: body,
                  last: title == _facts.last.$2,
                  leading: Icon(icon, size: 18, color: AppColors.label2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
