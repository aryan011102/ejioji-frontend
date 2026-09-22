import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/session.dart';
import '../features/account/presentation/account_page.dart';
import '../features/account/presentation/blocked_page.dart';
import '../features/account/presentation/premium_page.dart';
import '../features/account/presentation/profile_views_page.dart';
import '../features/account/presentation/settings_page.dart';
import '../features/account/presentation/subscription_page.dart';
import '../features/account/presentation/support_page.dart';
import '../features/account/presentation/take_break_page.dart';
import '../features/auth/presentation/otp_page.dart';
import '../features/auth/presentation/phone_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/chats/presentation/chats_page.dart';
import '../features/chats/presentation/conversation_page.dart';
import '../features/home/presentation/empty_feed_page.dart';
import '../features/home/presentation/filters_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/home/presentation/notifications_page.dart';
import '../features/insights/presentation/category_page.dart';
import '../features/insights/presentation/edit_sources_page.dart';
import '../features/onboarding/presentation/connect_accounts_page.dart';
import '../features/onboarding/presentation/consent_page.dart';
import '../features/onboarding/presentation/create_profile_page.dart';
import '../features/onboarding/presentation/netflix_upload_page.dart';
import '../features/onboarding/presentation/reading_page.dart';
import '../features/onboarding/presentation/spotify_upload_page.dart';
import '../features/profile/presentation/edit_info_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/safety/presentation/report_page.dart';
import '../features/sharing/presentation/shared_profile_page.dart';
import '../features/verification/presentation/digilocker_page.dart';
import '../features/verification/presentation/selfie_page.dart';
import '../features/verification/presentation/verify_hub_page.dart';
import '../features/verification/presentation/verify_result_page.dart';
import '../features/verification/presentation/why_matters_page.dart';
import '../shared/models/enums.dart';
import 'routes.dart';
import 'shell.dart';

/// One router, one redirect.
///
/// The redirect is the only auth guard in the app: no screen checks whether it
/// should be on screen, because a guard that lives on a screen is a guard
/// somebody forgets to add to the next screen.
final routerProvider = Provider<GoRouter>((ref) {
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.splash,
    // Rebuilds the redirect whenever the session moves.
    refreshListenable: _SessionSignal(ref),
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final here = state.matchedLocation;

      final inAuth = here == Routes.splash ||
          here.startsWith('/sign-in');
      final inOnboarding = here.startsWith('/onboarding');

      return switch (session.stage) {
        // Hold on the splash until the keychain has been read.
        SessionStage.unknown => here == Routes.splash ? null : Routes.splash,
        SessionStage.signedOut => inAuth ? null : Routes.splash,
        SessionStage.onboarding =>
          inOnboarding ? null : Routes.createProfile,
        // Only the start of setup is closed once it is done. The other
        // onboarding screens (permissions, connecting a source, an upload, the
        // reading screen) are opened again from Home and Edit sources, and
        // sending them home made those buttons do nothing.
        SessionStage.ready =>
          inAuth || here == Routes.createProfile ? Routes.home : null,
      };
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: Routes.phone, builder: (_, __) => const PhonePage()),
      GoRoute(
        path: Routes.otp,
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return OtpPage(
            phone: q['phone'] ?? '',
            dialCode: q['dial'] ?? '+91',
            // The server's own cooldown, carried across from the send, so the
            // Resend countdown matches what it will actually allow.
            retryAfterSeconds: int.tryParse(q['retry'] ?? '') ?? 60,
            debugCode: q['debug'],
          );
        },
      ),

      // Onboarding is a linear run, so it lives outside the shell — a tab bar
      // during setup would offer somewhere to go that does not exist yet.
      GoRoute(
        path: Routes.createProfile,
        builder: (_, __) => const CreateProfilePage(),
      ),
      GoRoute(
        path: Routes.consent,
        builder: (_, state) {
          // A single purpose when a source needs one; all of them otherwise.
          final one = state.uri.queryParameters['purpose'];
          return ConsentPage(
            purposes: one == null ? null : [ConsentPurpose.parse(one)],
          );
        },
      ),
      GoRoute(
        path: Routes.connect,
        builder: (_, state) => ConnectAccountsPage(
          onboarding: state.uri.queryParameters['more'] == null,
        ),
      ),
      GoRoute(
        path: Routes.netflixUpload,
        builder: (_, __) => const NetflixUploadPage(),
      ),
      GoRoute(
        path: Routes.spotifyUpload,
        builder: (_, __) => const SpotifyUploadPage(),
      ),
      GoRoute(
        path: Routes.reading,
        builder: (_, state) =>
            ReadingPage(runId: state.uri.queryParameters['run'] ?? ''),
      ),
      GoRoute(
        path: Routes.pickCategory,
        builder: (_, state) => CategoryPage(
          index: int.tryParse(state.pathParameters['index'] ?? '0') ?? 0,
          editing: false,
        ),
      ),
      GoRoute(
        path: Routes.profileReview,
        builder: (_, __) => const ProfilePage(mode: ProfileMode.review),
      ),

      // The three tabs share a shell so the bar does not rebuild between them.
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomePage()),
          GoRoute(path: Routes.chats, builder: (_, __) => const ChatsPage()),
          GoRoute(path: Routes.account, builder: (_, __) => const AccountPage()),
        ],
      ),

      GoRoute(path: Routes.filters, builder: (_, __) => const FiltersPage()),
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsPage(),
      ),

      GoRoute(
        path: Routes.conversation,
        builder: (_, state) =>
            ConversationPage(threadId: state.pathParameters['id'] ?? ''),
      ),

      GoRoute(
        path: Routes.person,
        builder: (_, state) {
          final args = state.extra as PersonArgs?;
          return ProfilePage(
            mode: ProfileMode.guest,
            candidate: args?.person,
            backLabel: args?.backLabel,
          );
        },
      ),

      GoRoute(
        path: Routes.feedEmptyFiltered,
        builder: (_, __) => const EmptyFeedPage(kind: EmptyFeedKind.filtered),
      ),
      GoRoute(
        path: Routes.feedEmptySeen,
        builder: (_, __) =>
            const EmptyFeedPage(kind: EmptyFeedKind.seenEveryone),
      ),

      GoRoute(path: Routes.verify, builder: (_, __) => const VerifyHubPage()),
      GoRoute(
        path: Routes.verifyWhy,
        builder: (_, __) => const WhyMattersPage(),
      ),
      GoRoute(
        path: Routes.digilocker,
        builder: (_, __) => const DigilockerStepsPage(),
      ),
      GoRoute(
        path: Routes.digilockerHandoff,
        builder: (_, __) => const DigilockerHandoffPage(),
      ),
      GoRoute(
        path: Routes.digilockerDone,
        builder: (_, __) =>
            const VerifyResultPage(route: VerifyRoute.digilocker),
      ),
      GoRoute(path: Routes.selfie, builder: (_, __) => const SelfieStepsPage()),
      GoRoute(
        path: Routes.selfieStep,
        builder: (_, state) => SelfieCapturePage(
          step: int.tryParse(state.pathParameters['step'] ?? '1') ?? 1,
        ),
      ),
      GoRoute(
        path: Routes.selfieDone,
        builder: (_, __) => const VerifyResultPage(route: VerifyRoute.selfie),
      ),
      GoRoute(
        path: Routes.verifyFailed,
        builder: (_, __) =>
            const VerifyErrorPage(route: VerifyRoute.digilocker),
      ),

      GoRoute(
        path: Routes.reportReason,
        builder: (_, state) => ReportReasonPage(
          userId: state.pathParameters['id'] ?? '',
          name: state.uri.queryParameters['name'],
          matchId: state.uri.queryParameters['match'],
        ),
      ),
      GoRoute(
        path: Routes.reportDetails,
        builder: (_, state) => ReportDetailsPage(
          userId: state.pathParameters['id'] ?? '',
          reason: state.uri.queryParameters['reason'],
          name: state.uri.queryParameters['name'],
          matchId: state.uri.queryParameters['match'],
        ),
      ),
      GoRoute(
        path: Routes.reportSent,
        builder: (_, state) =>
            ReportSentPage(name: state.uri.queryParameters['name']),
      ),

      GoRoute(
        path: Routes.sharedFriends,
        builder: (_, __) =>
            const SharedProfilePage(audience: SharedAudience.friends),
      ),
      GoRoute(
        path: Routes.sharedFamily,
        builder: (_, __) =>
            const SharedProfilePage(audience: SharedAudience.family),
      ),

      GoRoute(
        path: Routes.editProfile,
        builder: (_, __) => const ProfilePage(mode: ProfileMode.owner),
      ),
      GoRoute(path: Routes.editInfo, builder: (_, __) => const EditInfoPage()),
      GoRoute(
        path: Routes.editSources,
        builder: (_, __) => const EditSourcesPage(),
      ),
      GoRoute(
        path: Routes.editCategory,
        builder: (_, state) {
          final source = SourceProvider.parse(state.uri.queryParameters['source']);
          return CategoryPage(
            index: int.tryParse(state.pathParameters['index'] ?? '0') ?? 0,
            editing: true,
            source: source == SourceProvider.unknown ? null : source,
          );
        },
      ),

      GoRoute(path: Routes.settings, builder: (_, __) => const SettingsPage()),
      GoRoute(
        path: Routes.profileViews,
        builder: (_, __) => const ProfileViewsPage(),
      ),
      GoRoute(path: Routes.blocked, builder: (_, __) => const BlockedPage()),
      GoRoute(
        path: Routes.subscription,
        builder: (_, __) => const SubscriptionPage(),
      ),
      GoRoute(path: Routes.support, builder: (_, __) => const SupportPage()),
      GoRoute(
        path: Routes.takeBreak,
        builder: (_, __) => const TakeBreakPage(),
      ),
      GoRoute(path: Routes.premium, builder: (_, __) => const PremiumPage()),
    ],
  );
});

/// Bridges Riverpod to go_router's [Listenable]-based refresh.
class _SessionSignal extends ChangeNotifier {
  _SessionSignal(Ref ref) {
    ref.listen<Session>(sessionProvider, (_, __) => notifyListeners());
  }
}
