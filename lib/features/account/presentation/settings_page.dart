import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

/// Four groups: your account, appearance, help, and the one that ends things.
///
/// No group carries a footnote. The rules that need stating are stated where
/// they are acted on — inside the sheet that deletes, or on the page that
/// blocks — rather than as encouragement under a list.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {

  Future<void> _delete() async {
    final choice = await showAppActionSheet(
      context,
      title: 'Delete your account?',
      message: 'Your profile, your insights, your photos and every chat go '
          'with it. This cannot be undone.',
      actions: const [
        SheetAction('Delete everything', destructive: true),
        // Offered next to the ending, because most people who open this sheet
        // want the other thing.
        SheetAction('Take a break instead'),
      ],
    );
    if (!mounted) return;
    if (choice == 0) {
      await _confirmDelete();
    } else if (choice == 1) {
      if (mounted) context.push(Routes.takeBreak);
    }
  }

  /// Deleting is immediate and final: no grace period, no undo, and no code
  /// by SMS. The server asks for the word to be typed, and this is where that
  /// happens, because a sheet button alone is one mistaken tap away from
  /// erasing an account.
  Future<void> _confirmDelete() async {
    final typed = await showDeleteConfirmation(context);
    if (typed == null || !mounted) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount(confirmation: typed);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
      return;
    } finally {
      // The tokens are gone either way, so the session must follow. A person
      // who has just asked to be erased must not be left signed in.
      if (mounted) await ref.read(sessionProvider.notifier).onSessionLost();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium does not exist yet: no plans, no purchase, no entitlement. The
    // rows that depended on it are shown in their free reading and say so,
    // rather than offering a switch that cannot be honoured.

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Settings',
        backLabel: 'You',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          SectionGroup(
            header: 'Your account',
            children: [
              AppRow(
                label: 'Profile views',
                subtitle: 'Not counted yet',
                leading: const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () => context.push(Routes.profileViews),
              ),
              AppRow(
                label: 'Stealth mode',
                subtitle: 'Browse without being found',
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.label2,
                ),
                premium: true,
                onTap: () async {
                  final c = await showAppActionSheet(
                    context,
                    title: 'Stealth mode is not built yet',
                    message: 'The idea is to browse without appearing in '
                        "anyone's feed. Nothing supports it yet. Taking a "
                        'break hides your profile completely in the meantime.',
                    actions: const [SheetAction('Take a break instead')],
                  );
                  if (c == 0 && context.mounted) {
                    context.push(Routes.takeBreak);
                  }
                },
              ),
              AppRow(
                label: 'Blocked users',
                leading: const Icon(
                  Icons.block,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () => context.push(Routes.blocked),
              ),
              AppRow(
                label: 'Subscription details',
                value: 'Free',
                last: true,
                leading: const Icon(
                  Icons.credit_card,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () => context.push(Routes.subscription),
              ),
            ],
          ),
          // Dark-only, so the control is present and honest about it rather
          // than absent and unexplained.
          const SectionGroup(
            header: 'Appearance',
            children: [
              AppRow(
                label: 'Dark',
                subtitle: 'ejioji is dark only, for now',
                last: true,
                leading: Icon(
                  Icons.nightlight_round,
                  size: 18,
                  color: AppColors.label2,
                ),
              ),
            ],
          ),
          SectionGroup(
            header: 'Help and about',
            children: [
              AppRow(
                label: 'Message the founder',
                subtitle: 'Goes straight to my inbox',
                leading: const Icon(
                  Icons.mail_outline,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () => showAppActionSheet(
                  context,
                  title: 'Message the founder',
                  message: 'hi@ejioji.com — I read these myself.',
                  actions: const [
                    SheetAction('Open Mail'),
                    SheetAction('Copy address'),
                  ],
                ),
              ),
              AppRow(
                label: 'Support and privacy',
                leading: const Icon(
                  Icons.support_outlined,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () => context.push(Routes.support),
              ),
              AppRow(
                label: 'Rate ejioji on the App Store',
                last: true,
                leading: const Icon(
                  Icons.star_outline,
                  size: 18,
                  color: AppColors.label2,
                ),
                control: const Icon(
                  Icons.open_in_new,
                  size: 15,
                  color: AppColors.label4,
                ),
                onTap: () {},
              ),
            ],
          ),
          SectionGroup(
            children: [
              AppRow(
                label: 'Delete account',
                destructive: true,
                last: true,
                leading: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.destructive,
                ),
                onTap: _delete,
              ),
            ],
          ),
          Center(child: Text('ejioji 1.0 (build 1)', style: AppText.micro)),
        ],
      ),
    );
  }
}
