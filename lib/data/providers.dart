import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/session/session.dart';
import '../core/storage/device.dart';
import '../core/storage/token_store.dart';
import '../shared/models/activity.dart';
import '../shared/models/chat.dart';
import '../shared/models/connection.dart';
import '../shared/models/consent.dart';
import '../shared/models/media.dart';
import '../shared/models/person.dart';
import '../shared/models/profile.dart';
import '../shared/models/social.dart';
import '../shared/models/tile.dart';
import 'activity_repository.dart';
import 'auth_repository.dart';
import 'chat_repository.dart';
import 'consent_repository.dart';
import 'matching_repository.dart';
import 'media_repository.dart';
import 'profile_repository.dart';
import 'push_controller.dart';
import 'sharing_repository.dart';
import 'sources_repository.dart';
import 'trust_repository.dart';
import 'verification_repository.dart';

/// One client for the whole app.
///
/// A refused refresh ends the session here rather than inside the client, so
/// the client never has to know what a route is.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.build(
    ref,
    onLost: () async => ref.read(sessionProvider.notifier).onSessionLost(),
  );
});

/// The push token for this install, kept in step with the server for as long
/// as somebody is signed in. Does nothing at all in a build without a
/// Firebase project, or in the browser.
final pushRegistrationProvider = Provider<PushRegistration>(
  (ref) => PushRegistration(ref.watch(authRepositoryProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
    ref.watch(deviceIdentityProvider),
  ),
);

final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => ConsentRepository(
    ref.watch(apiClientProvider),
    ref.watch(deviceIdentityProvider),
  ),
);

final sourcesRepositoryProvider = Provider<SourcesRepository>(
  (ref) => SourcesRepository(ref.watch(apiClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(apiClientProvider)),
);

final matchingRepositoryProvider = Provider<MatchingRepository>(
  (ref) => MatchingRepository(ref.watch(apiClientProvider)),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(apiClientProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

final trustRepositoryProvider = Provider<TrustRepository>(
  (ref) => TrustRepository(ref.watch(apiClientProvider)),
);

final sharingRepositoryProvider = Provider<SharingRepository>(
  (ref) => SharingRepository(ref.watch(apiClientProvider)),
);

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => VerificationRepository(ref.watch(apiClientProvider)),
);

// The reads.
//
// One provider per thing the server holds, so two screens showing the same
// thing show the same thing. They are `autoDispose` because almost none of
// this is worth caching past the screen that asked for it: a feed, a
// conversation list and a publish state all go stale the moment somebody else
// acts, and a stale profile is how a screen ends up arguing with the server.
//
// Anything that changes state calls `invalidate` on what it changed.

final myProfileProvider = FutureProvider.autoDispose<MyProfile>(
  (ref) => ref.watch(profileRepositoryProvider).load(),
);

/// Your own social links, switches included. Only matches ever see them.
final mySocialsProvider = FutureProvider.autoDispose<List<SocialLink>>(
  (ref) => ref.watch(profileRepositoryProvider).socials(),
);

final profileOptionsProvider = FutureProvider<ProfileOptions>(
  (ref) => ref.watch(profileRepositoryProvider).options(),
);

final promptBankProvider = FutureProvider.autoDispose<PromptBank>(
  (ref) => ref.watch(profileRepositoryProvider).prompts(),
);

/// The notices and this person's grants, together. Read before any connect
/// screen, because the server refuses to authorize a source whose purpose is
/// not open.
/// Where this person's DigiLocker verification stands, derived by the server
/// from their profile on every read.
final verificationProvider = FutureProvider.autoDispose<Verification>(
  (ref) => ref.watch(verificationRepositoryProvider).load(),
);

final consentProvider = FutureProvider.autoDispose<ConsentState>(
  (ref) => ref.watch(consentRepositoryProvider).load(),
);

final connectionsProvider = FutureProvider.autoDispose<List<Connection>>(
  (ref) => ref.watch(sourcesRepositoryProvider).connections(),
);

/// Every tile the server has computed, picked or not.
final candidatesProvider = FutureProvider.autoDispose<List<Insight>>(
  (ref) => ref.watch(sourcesRepositoryProvider).candidates(),
);

/// What is behind each tile, picked or not.
final tileMediaListProvider = FutureProvider.autoDispose<List<TileMediaEntry>>(
  (ref) => ref.watch(profileRepositoryProvider).tileMedia(),
);

final mediaPoolProvider = FutureProvider.autoDispose<List<MediaAsset>>(
  (ref) => ref.watch(mediaRepositoryProvider).pool(),
);

final preferencesProvider = FutureProvider.autoDispose<MatchPreferences>(
  (ref) => ref.watch(matchingRepositoryProvider).preferences(),
);

final incomingRequestsProvider =
    FutureProvider.autoDispose<List<PendingRequest>>(
  (ref) => ref.watch(matchingRepositoryProvider).incoming(),
);

final outgoingRequestsProvider = FutureProvider.autoDispose<OutgoingRequests>(
  (ref) => ref.watch(matchingRepositoryProvider).outgoing(),
);

final matchesProvider = FutureProvider.autoDispose<List<Match>>(
  (ref) => ref.watch(matchingRepositoryProvider).matches(),
);

final blockedProvider = FutureProvider.autoDispose<List<BlockedPerson>>(
  (ref) => ref.watch(matchingRepositoryProvider).blocks(),
);

final profileViewsProvider = FutureProvider.autoDispose<ProfileViews>(
  (ref) => ref.watch(matchingRepositoryProvider).views(),
);

final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>(
  (ref) => ref.watch(chatRepositoryProvider).conversations(),
);

/// The Notifications page. Home watches it for the bell's dot, and the shell
/// reloads it on every live event, so the dot moves without a pull to refresh.
final activityProvider = FutureProvider.autoDispose<ActivityPage>(
  (ref) => ref.watch(activityRepositoryProvider).load(),
);
