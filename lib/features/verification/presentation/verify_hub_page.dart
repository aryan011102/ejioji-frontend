import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';

/// Two routes, one door.
///
/// Either route opens chat. Doing both gives gold, which unlocks nothing at
/// all — it exists because *is this person real* is the question a family asks
/// first, and it deserves an answer that took more than a minute to earn. So
/// gold is stated as a consequence of doing both, never as a third task.
class VerifyHubPage extends ConsumerWidget {
  const VerifyHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(sessionProvider).tier;

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Verify',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          LargeTitle(
            switch (tier) {
              VerificationTier.gold => 'Both checks are done.',
              VerificationTier.blue =>
                "You're verified. There's one more if you want it.",
              VerificationTier.none => 'Two ways. Either one opens chat.',
            },
            subtitle: tier == VerificationTier.gold
                ? 'An ID and a photo were both checked, so your profile '
                    'carries the gold tick.'
                : "Pick whichever you'd rather do. Doing both gives the gold "
                    'tick.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Column(
              children: [
                _RouteCard(
                  icon: Icons.description_outlined,
                  title: 'DigiLocker',
                  body: 'Sign in with your Aadhaar-linked number and share '
                      'your name and date of birth. We never see the number '
                      'itself.',
                  cost: 'About a minute · instant',
                  done: tier != VerificationTier.none,
                  onTap: () => context.push(Routes.digilocker),
                ),
                const SizedBox(height: 12),
                _RouteCard(
                  icon: Icons.face_retouching_natural_outlined,
                  title: 'Selfie and liveness',
                  body: 'Copy a pose on screen, take a selfie, add one photo '
                      'from your gallery.',
                  cost: 'Two minutes · reviewed in 24h',
                  done: false,
                  onTap: () => context.push(Routes.selfie),
                ),
                const SizedBox(height: 12),
                _GoldCard(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              22,
              Insets.gutter,
              0,
            ),
            child: SectionGroup(
              children: [
                AppRow(
                  label: 'Why this matters',
                  subtitle: "What a tick means, and what it doesn't",
                  last: true,
                  leading: const Icon(
                    Icons.help_outline,
                    size: 18,
                    color: AppColors.label2,
                  ),
                  onTap: () => context.push(Routes.verifyWhy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.cost,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Stated up front, in minutes. Someone choosing between two checks is
  /// choosing on time, and hiding it does not make them pick the longer one.
  final String cost;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: done ? null : onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
        decoration: BoxDecoration(
          color: AppColors.row,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconPlate(
              icon,
              size: 40,
              radius: 12,
              background: AppColors.blueSoft,
              foreground: AppColors.blue,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: AppText.title3.copyWith(fontSize: 17)),
                      if (done) ...[
                        const SizedBox(width: 7),
                        const VerifiedTick(
                          tier: VerificationTier.blue,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(body, style: AppText.footnote.copyWith(fontSize: 13.5)),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: done ? AppColors.blueSoft : AppColors.fill2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          done ? 'Verified' : cost,
                          style: AppText.caption.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: done ? AppColors.blue : AppColors.label2,
                          ),
                        ),
                      ),
                      if (!done) ...[
                        const SizedBox(width: 7),
                        Text(
                          'Start',
                          style: AppText.caption.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 22,
              color: AppColors.onAccent,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Do both, get the gold tick', style: AppText.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  'It unlocks nothing extra. It says an ID and a photo were '
                  'both checked, which is the thing families ask about.',
                  style: AppText.footnote.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
