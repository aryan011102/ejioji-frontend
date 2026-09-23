import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/models/social.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/social_mark.dart';
import '../../profile/presentation/social_link_sheet.dart';

/// Five groups: your account, your socials, appearance, help, and the one that
/// ends things.
///
/// Only Socials carries a footnote, because its switches are where the rule is
/// acted on. Otherwise the rules that need stating are stated where
/// they are acted on — inside the sheet that deletes, or on the page that
/// blocks — rather than as encouragement under a list.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// A switch waiting on the server, so a second tap cannot race the first.
  SocialNetwork? _switching;

  /// Share a link with matches, or keep it saved and show it to nobody.
  Future<void> _setShown(SocialNetwork network, bool shown) async {
    setState(() => _switching = network);
    try {
      await ref.read(profileRepositoryProvider).setSocialShown(network, shown);
      ref.invalidate(mySocialsProvider);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _switching = null);
    }
  }

  /// Waiting on the server for the stealth switch.
  bool _stealthBusy = false;

  /// Out of every feed while still browsing and asking, or back in. Free for
  /// now: there is no premium to check against yet.
  Future<void> _setStealth(bool on) async {
    setState(() => _stealthBusy = true);
    final repo = ref.read(profileRepositoryProvider);
    final session = ref.read(sessionProvider.notifier);
    try {
      if (on) {
        session.onPublishChanged(await repo.enterStealth());
      } else {
        await repo.leaveStealth();
        session.onProfileChanged(await repo.load());
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _stealthBusy = false);
    }
  }

  /// Instagram, X and LinkedIn: a switch where there is a link, and the way
  /// to add one where there is not.
  Widget _socials() {
    final links = {
      for (final l in ref.watch(mySocialsProvider).valueOrNull ??
          const <SocialLink>[])
        l.network: l,
    };
    return SectionGroup(
      header: 'Socials',
      footer: 'Shown only to people you match with, and only while the '
          'switch is on. Never on your profile card or in the feed.',
      children: [
        for (final n in SocialNetwork.shown)
          if (links[n] case final link?)
            AppRow(
              label: n.label,
              subtitle: link.display,
              leading: SocialMark(n, size: 26),
              last: n == SocialNetwork.shown.last,
              onTap: () => showSocialLinkSheet(
                context,
                network: n,
                existing: link,
              ),
              control: AppSwitch(
                value: link.shown,
                onChanged: _switching == null
                    ? (v) => _setShown(n, v)
                    : null,
              ),
            )
          else
            AppRow(
              label: n.label,
              subtitle: 'Not added',
              leading: SocialMark(n, size: 26),
              last: n == SocialNetwork.shown.last,
              onTap: () => showSocialLinkSheet(context, network: n),
            ),
      ],
    );
  }

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
                subtitle: 'Only people you ask can see you',
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.label2,
                ),
                control: AppSwitch(
                  value: ref.watch(sessionProvider).publish?.stealth ?? false,
                  onChanged: _stealthBusy ? null : _setStealth,
                ),
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
          _socials(),
          // Dark-only, so the control is present and honest about it rather
          // than absent and unexplained.
          const SectionGroup(
            header: 'Appearance',
            children: [
              AppRow(
                label: 'Dark',
                subtitle: 'theonebytwo is dark only, for now',
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
                  message: 'pritika@theonebytwo.com — I read these myself.',
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
                label: 'Rate theonebytwo on the App Store',
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
          Center(child: Text('theonebytwo 1.0 (build 1)', style: AppText.micro)),
        ],
      ),
    );
  }
}
