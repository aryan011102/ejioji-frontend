import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/blind_controller.dart';
import '../../../data/feed_controller.dart';
import '../../../data/providers.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';
import '../../blind/presentation/blind_page.dart';
import '../../profile/presentation/person_actions.dart';
import '../../profile/presentation/profile_page.dart';
import 'empty_feed_page.dart';

/// Home, and Home turned over.
///
/// Holding the Home icon flips the screen to Go blind and back
/// (blindModeProvider). Both faces stay alive once built, so flipping back
/// finds the card, the scroll and the place on the plane where they were left.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
    value: ref.read(blindModeProvider) ? 1 : 0,
  );

  /// Built the first time it is turned to, and kept after.
  late bool _blindBuilt = ref.read(blindModeProvider);

  @override
  void initState() {
    super.initState();
    if (_blindBuilt) _startBlind();
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _startBlind() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(blindProvider.notifier).start();
      });

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(blindModeProvider, (_, blind) {
      if (blind && !_blindBuilt) {
        setState(() => _blindBuilt = true);
        _startBlind();
      }
      blind ? _flip.forward() : _flip.reverse();
    });

    return ColoredBox(
      color: AppColors.group,
      child: AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_flip.value);
          final turned = t >= 0.5;
          // Half a turn about the vertical axis: Home goes edge-on, and Blind
          // comes round from the other side.
          final angle = turned ? (t - 1) * math.pi : t * math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0011)
              ..rotateY(angle),
            child: Stack(
              children: [
                // Offstage keeps a face's state while the other one shows.
                Offstage(offstage: turned, child: const _Deck()),
                if (_blindBuilt)
                  Offstage(offstage: !turned, child: const BlindPage()),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Home is the viewer's view.
///
/// The screen a stranger's profile is shown on is the screen the app opens on,
/// so it carries the app's chrome as well as the profile's, and the profile
/// underneath is the same component rather than a copy of it.
///
/// Home owns the deck. The profile takes the current person as a parameter,
/// so the card being looked at and the card being acted on cannot come apart.
class _Deck extends ConsumerWidget {
  const _Deck();

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
      final step = feedMissingStep(error);
      if (step != null) {
        return AppScaffold(
          child: EmptyState(
            icon: step.icon,
            title: step.title,
            body: step.body,
            primaryLabel: step.label,
            onPrimary: () async {
              await context.push<Object?>(step.route);
              // Whatever they did there, ask again: the server decides.
              ref.read(feedProvider.notifier).refresh();
            },
          ),
        );
      }
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
          title: 'You are not discoverable yet',
          body: session.isUnderReview
              ? 'A moderator is looking at your profile. It is hidden until '
                  'that is finished.'
              : 'Finish your profile. Till then, you may look around but no '
                  'one can see your profile.',
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

/// The feed refuses three ways before anything is wrong: no matching consent,
/// no profile, no "show me" choice. Each is a step still to take, so each gets
/// the button that takes it rather than "That did not load".
({IconData icon, String title, String body, String label, String route})?
    feedMissingStep(Object error) {
  if (error is! ApiException) return null;
  return switch (error.code) {
    'consent_required' => (
        icon: Icons.handshake_outlined,
        title: 'One permission first',
        body: 'Home suggests people to you and you to them. That needs your '
            'permission for matching.',
        label: 'Review permission',
        route: '${Routes.consent}?purpose=${ConsentPurpose.matching.wire}',
      ),
    'preferences_needed' => (
        icon: Icons.tune,
        title: 'Who would you like to see?',
        body: 'Choose who is shown to you, and we will start looking.',
        label: 'Choose',
        route: Routes.filters,
      ),
    'profile_needed' => (
        icon: Icons.person_outline,
        title: 'Your details first',
        body: 'Add your details so we know who to suggest.',
        label: 'Add my details',
        route: Routes.editProfile,
      ),
    _ => null,
  };
}

class _HomeBar extends ConsumerWidget {
  const _HomeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Something new on the Notifications page. A dot rather than a count: the
    // page is for catching up, and a number on a bell reads like a debt.
    final fresh =
        (ref.watch(activityProvider).valueOrNull?.newCount ?? 0) > 0;
    // Only while a card is up: on an empty or loading feed there is nobody to
    // save or report.
    final person = ref.watch(feedProvider.select((f) => f.current));
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
          // Notifications, then the bookmark and the "···" for the card on
          // screen. The profile underneath draws none of these itself: this
          // bar floats over its bar, and anything there would sit under here
          // where no tap can reach it.
          NavIconButton(
            icon: Icons.notifications_none,
            semanticLabel:
                fresh ? 'Notifications, something new' : 'Notifications',
            onTap: () => context.push(Routes.notifications),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none,
                  size: 22,
                  color: AppColors.accent,
                ),
                if (fresh)
                  Positioned(
                    key: const ValueKey('bell-dot'),
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.pink,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.group, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (person != null) ...[
            SaveProfileButton(person: person),
            NavIconButton(
              icon: Icons.more_horiz,
              semanticLabel: 'More about ${person.firstName}',
              onTap: () => showPersonMenu(
                context,
                ref,
                person,
                onBlocked: () => ref.read(feedProvider.notifier).dropCurrent(),
              ),
            ),
          ],
          const SizedBox(width: 7),
        ],
      ),
    );
  }
}
