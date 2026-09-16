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

/// The count is free; the faces are not.
///
/// The blur is on the page rather than behind a paywall, because a wall you
/// cannot see past is easy to dismiss and a blurred face is not.
class ProfileViewsPage extends ConsumerWidget {
  const ProfileViewsPage({super.key});

  static const _viewers = <(String, String, String, Color)>[
    ('Rohan Mehta', 'Bengaluru', '2h', Color(0xFF7B8E88)),
    ('Kabir Shah', 'Bengaluru', '5h', Color(0xFF8B7F6E)),
    ('Arjun Menon', 'Mumbai', 'Yesterday', Color(0xFF6E7A93)),
    ('Vikram Nair', 'Bengaluru', 'Yesterday', Color(0xFF93867B)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(sessionProvider).premium;

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Profile views',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.titleGutter,
              22,
              Insets.titleGutter,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('12', style: AppText.largeTitle.copyWith(fontSize: 44)),
                const SizedBox(height: 4),
                Text(
                  'people opened your profile this week. Five of them more '
                  'than once.',
                  style: AppText.callout,
                ),
              ],
            ),
          ),
          SectionGroup(
            children: [
              for (final (name, where, seenAt, seed) in _viewers)
                AppRow(
                  label: premium ? name : 'Someone in $where',
                  subtitle: premium ? where : 'Hidden until you upgrade',
                  value: seenAt,
                  last: name == _viewers.last.$1,
                  leading: Avatar(
                    seedColor: seed,
                    size: 29,
                    blurred: !premium,
                  ),
                ),
            ],
          ),
          if (!premium)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              child: Pressable(
                onTap: () => context.push(Routes.premium),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.promo,
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'See who they are',
                        style: AppText.title3.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Premium shows the names and the faces. The count is '
                        'always free.',
                        style: AppText.footnote.copyWith(
                          fontSize: 13.5,
                          color: const Color(0xC7FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.titleGutter,
              16,
              Insets.titleGutter,
              0,
            ),
            child: Text(
              premium
                  ? 'With stealth mode on, your own views never appear on '
                      "anyone's list."
                  : 'Views are counted for everyone. Stealth mode keeps you '
                      "off other people's lists too.",
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
