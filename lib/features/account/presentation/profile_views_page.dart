import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../data/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/models/person.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

/// Who has looked at your profile, most recently first.
///
/// A look is a profile on someone's screen for 3 seconds, and it is never
/// recorded while they are in stealth or their own profile is not showing.
/// The list is checked on the server every time: someone who has since
/// blocked you, gone into stealth or dropped out of your filters is not here.
///
/// Nothing here is invented. The earlier version of this screen listed four
/// made-up people, and a fake viewer is indistinguishable from a real one.
///
/// This will be Premium, with the faces behind a blur for everyone else
/// ([Avatar.blurred]). There is no billing yet, so everyone sees everything;
/// the gate belongs on the server, not in this screen.
class ProfileViewsPage extends ConsumerWidget {
  const ProfileViewsPage({super.key});

  static String _when(ProfileVisitor v) {
    final day = dayLabel(v.lastViewedAt);
    final last = switch (day) {
      'Today' || 'Yesterday' => day.toLowerCase(),
      _ => 'on $day',
    };
    return v.visits == 1
        ? 'Looked $last'
        : 'Looked ${v.visits} times, last $last';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(profileViewsProvider);

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Profile views',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      child: views.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(profileViewsProvider),
        ),
        data: (seen) => seen.visitors.isEmpty
            ? const EmptyState(
                icon: Icons.visibility_outlined,
                title: 'Nobody has looked yet',
                body: 'When someone spends a few seconds on your profile, they '
                    'show up here. People in stealth mode are never counted.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(profileViewsProvider.future),
                child: ListView(
                  padding: const EdgeInsets.only(top: 18, bottom: 40),
                  children: [
                    SectionGroup(
                      header: seen.total == 1
                          ? '1 person has looked'
                          : '${seen.total} people have looked',
                      footer: 'Someone shows here once your profile has been '
                          'on their screen for a few seconds. Looking at a '
                          "profile puts you on that person's list too, unless "
                          'you are in stealth mode.',
                      children: [
                        for (final v in seen.visitors)
                          AppRow(
                            label: '${v.person.firstName}, ${v.person.age}',
                            subtitle: _when(v),
                            last: v == seen.visitors.last,
                            leading: Avatar(
                              seedColor: const Color(0xFF8E7B93),
                              imageUrl: v.person.photos.firstOrNull?.stillUrl,
                              size: 29,
                            ),
                            onTap: () => context.push(
                              Routes.person,
                              extra: PersonArgs(
                                person: v.person,
                                backLabel: 'Views',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
