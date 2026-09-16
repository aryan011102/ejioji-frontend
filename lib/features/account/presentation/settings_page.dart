import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/controls.dart';
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
  bool _stealth = false;

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
      // TODO(backend): DELETE Api.meDelete, then clear the session. Tokens are
      // cleared regardless of whether the call succeeds.
      await ref.read(sessionProvider.notifier).signOut();
    } else if (choice == 1) {
      if (mounted) context.push(Routes.takeBreak);
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(sessionProvider).premium;

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
                subtitle: '12 this week',
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
                premium: !premium,
                control: premium
                    ? AppSwitch(
                        value: _stealth,
                        onChanged: (v) => setState(() => _stealth = v),
                      )
                    : null,
                onTap: premium
                    ? null
                    : () async {
                        final c = await showAppActionSheet(
                          context,
                          title: 'Stealth mode is part of Premium',
                          message: "Browse without appearing in anyone's feed "
                              '— and without landing on their views list.',
                          actions: const [
                            SheetAction("See what's in Premium"),
                          ],
                        );
                        if (c == 0 && context.mounted) {
                          context.push(Routes.premium);
                        }
                      },
              ),
              AppRow(
                label: 'Blocked users',
                value: '2',
                leading: const Icon(
                  Icons.block,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () => context.push(Routes.blocked),
              ),
              AppRow(
                label: 'Subscription details',
                value: premium ? 'Premium' : 'Free',
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
