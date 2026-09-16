import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/feed_controller.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';
import '../../profile/presentation/profile_page.dart';
import 'empty_feed_page.dart';

/// Home is the viewer's view.
///
/// The screen a stranger's profile is shown on is the screen the app opens on,
/// so it carries the app's chrome as well as the profile's, and the profile
/// underneath is the same component rather than a copy of it.
///
/// Home owns the deck. The profile takes the current person as a parameter,
/// so the card being looked at and the card being acted on cannot come apart.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final session = ref.watch(sessionProvider);

    return Stack(
      children: [
        _body(context, ref, feed, session),
        // Home's own bar floats over the profile rather than pushing it down,
        // so the wall reaches the top of the screen.
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.paddingOf(context).top,
          child: const _HomeBar(),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    FeedState feed,
    Session session,
  ) {
    if (feed.loading) return const AppScaffold(child: LoadingView());

    final error = feed.error;
    if (error != null && feed.cards.isEmpty) {
      return AppScaffold(
        child: ErrorView(
          error: error,
          onRetry: () => ref.read(feedProvider.notifier).refresh(),
        ),
      );
    }

    // Someone who has not published is browsing but is not being shown to
    // anyone. Saying so here is the honest place: they will otherwise wonder
    // why nothing is coming back.
    if (!session.isVisible && feed.cards.isEmpty) {
      return AppScaffold(
        child: EmptyState(
          icon: Icons.visibility_off_outlined,
          title: 'You are not showing yet',
          body: session.isUnderReview
              ? 'A moderator is looking at your profile. It is hidden until '
                  'that is finished.'
              : 'Finish your profile and publish it. Until you do, you can '
                  'look around but nobody is shown you.',
          primaryLabel: session.isUnderReview ? null : 'Finish my profile',
          onPrimary: session.isUnderReview
              ? null
              : () => context.push(Routes.editProfile),
        ),
      );
    }

    final person = feed.current;
    if (person == null) {
      // Two different endings. Nobody matched the filters at all, or they have
      // been through everyone who did.
      return EmptyFeedPage(
        kind: feed.cards.isEmpty
            ? EmptyFeedKind.filtered
            : EmptyFeedKind.seenEveryone,
        onRetry: () => ref.read(feedProvider.notifier).refresh(),
      );
    }

    return ProfilePage(
      // Keyed on the person, so moving to the next card resets the scroll
      // position and the sheet state instead of carrying the last one over.
      key: ValueKey(person.userId),
      mode: ProfileMode.viewer,
      candidate: person,
    );
  }
}

class _HomeBar extends StatelessWidget {
  const _HomeBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: Insets.md),
          Pressable(
            onTap: () => context.push(Routes.filters),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filters',
                    style: AppText.navAction.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Pressable(
            onTap: () => context.push(Routes.notifications),
            semanticLabel: 'Notifications',
            child: const Padding(
              padding: EdgeInsets.fromLTRB(6, 6, 14, 2),
              child: Icon(
                Icons.notifications_none,
                size: 22,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
