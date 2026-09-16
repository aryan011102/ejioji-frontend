import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';

/// The third tab. Four jobs, in the order they matter: who you are, how
/// believable you are, what you could become, and everything else.
///
/// The profile is a row rather than a hero — this is the account page, not the
/// profile, and tapping it goes to the thing itself.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return AppScaffold(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 150),
        children: [
          const LargeTitle('You'),
          if (session.paused)
            _PausedBanner(
              onResume: () =>
                  ref.read(sessionProvider.notifier).onPaused(paused: false),
            ),
          Opacity(
            opacity: session.paused ? 0.5 : 1,
            child: _ProfileCard(
              tier: session.tier,
              onTap: () => context.push(Routes.editProfile),
            ),
          ),
          if (session.tier == VerificationTier.none)
            _Invitation(
              icon: Icons.check,
              tint: AppColors.blueSoft,
              iconColor: AppColors.blue,
              title: 'Verify to chat, and get a tick',
              body: 'Two ways, either one opens chat. Takes a couple of '
                  'minutes.',
              onTap: () => context.push(Routes.verify),
            )
          else
            SectionGroup(
              footer: session.tier == VerificationTier.gold
                  ? 'Both checks passed. The gold tick says an ID and a photo '
                      'were verified.'
                  : 'One check passed. Do the other one for the gold tick.',
              children: [
                AppRow(
                  label: session.tier == VerificationTier.gold
                      ? 'Verified — gold'
                      : 'Verified — blue',
                  subtitle: session.tier == VerificationTier.gold
                      ? 'ID and photo'
                      : 'One check',
                  value: session.tier == VerificationTier.gold ? null : 'Add',
                  last: true,
                  leading: VerifiedTick(tier: session.tier, size: 22),
                  onTap: () => context.push(Routes.verify),
                ),
              ],
            ),
          if (session.premium)
            SectionGroup(
              children: [
                AppRow(
                  label: 'Premium is on',
                  subtitle: 'Renews 8 October',
                  last: true,
                  leading: const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  onTap: () => context.push(Routes.subscription),
                ),
              ],
            )
          else
            _PremiumPromo(onTap: () => context.push(Routes.premium)),
          SectionGroup(
            children: [
              AppRow(
                label: 'Settings',
                last: true,
                leading: const Icon(
                  Icons.settings,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () => context.push(Routes.settings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.tier, required this.onTap});

  final VerificationTier tier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionGroup(
      children: [
        PressableRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Avatar(seedColor: Demo.meSeed, size: 62),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              Demo.meName,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title3.copyWith(fontSize: 19),
                            ),
                          ),
                          if (tier != VerificationTier.none) ...[
                            const SizedBox(width: 6),
                            VerifiedTick(tier: tier, size: 19),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '8 insights · 3 photos',
                        style: AppText.footnote.copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'View and edit profile',
                        style: AppText.footnote.copyWith(
                          fontSize: 13,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.label4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Invitation extends StatelessWidget {
  const _Invitation({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 22),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          decoration: BoxDecoration(
            color: AppColors.row,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: AppText.caption.copyWith(
                        fontSize: 12.5,
                        color: AppColors.label2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.label4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumPromo extends StatelessWidget {
  const _PremiumPromo({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 22),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.promo,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: AppColors.pink,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'ejioji Premium',
                    style: AppText.title3.copyWith(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'See who viewed you, browse unseen, and put more of yourself '
                'on the wall.',
                style: AppText.footnote.copyWith(
                  fontSize: 13.5,
                  color: const Color(0xC7FFFFFF),
                ),
              ),
              const SizedBox(height: 13),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.label,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  "See what's in it",
                  style: AppText.footnote.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C1226),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Impossible to miss, and impossible to read as a punishment.
class _PausedBanner extends StatelessWidget {
  const _PausedBanner({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.row,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const IconPlate(
                  Icons.visibility_off_outlined,
                  size: 38,
                  radius: 19,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your profile is hidden',
                        style: AppText.bodyStrong,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Nobody new can find you. Your chats still work.',
                        style: AppText.caption.copyWith(
                          fontSize: 12.5,
                          color: AppColors.label2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Pressable(
              onTap: onResume,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'Show my profile',
                  style: AppText.button.copyWith(
                    fontSize: 16,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
