import 'dart:async';

import 'package:ejioji/core/session/session.dart';
import 'package:ejioji/data/feed_controller.dart';
import 'package:ejioji/data/matching_repository.dart';
import 'package:ejioji/data/providers.dart';
import 'package:ejioji/features/account/presentation/settings_page.dart';
import 'package:ejioji/shared/models/person.dart';
import 'package:ejioji/shared/models/premium.dart';
import 'package:ejioji/shared/models/social.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A signed-in session that records sign-outs instead of calling the server.
class _Session extends SessionController {
  int signOuts = 0;

  @override
  Session build() => const Session(stage: SessionStage.ready, userId: 'a');

  @override
  Future<void> signOut() async {
    signOuts++;
    state = const Session(stage: SessionStage.signedOut);
  }

  void become(String? userId) => state = Session(
        stage: userId == null ? SessionStage.signedOut : SessionStage.ready,
        userId: userId,
      );
}

/// Answers each feed request with a page whose cursor is the request's
/// number, so a test can tell whose deck it is holding.
class _Matching implements MatchingRepository {
  int feeds = 0;

  @override
  Future<FeedPage> feed({int? after, int limit = 10}) async =>
      FeedPage(cards: const [], nextCursor: ++feeds);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Session> _openSettings(WidgetTester tester) async {
  final session = _Session();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => session),
        premiumProvider.overrideWith((_) => Completer<PremiumStatus>().future),
        profileViewsProvider
            .overrideWith((_) => Completer<ProfileViews>().future),
        mySocialsProvider.overrideWith((_) async => const <SocialLink>[]),
        appVersionProvider.overrideWith((_) async => null),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Log out'), 200);
  // Partly in view is enough for scrollUntilVisible, not for a tap.
  await tester.ensureVisible(find.text('Log out'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Log out'));
  await tester.pumpAndSettle();
  return session;
}

void main() {
  group('log out from Settings', () {
    testWidgets('asks first, says it is every phone, then signs out',
        (tester) async {
      final session = await _openSettings(tester);
      expect(find.text('Log out?'), findsOneWidget);
      expect(find.textContaining('every phone'), findsOneWidget);
      expect(session.signOuts, 0);

      // The sheet's button, not the row behind it.
      await tester.tap(find.text('Log out').last);
      await tester.pumpAndSettle();
      expect(session.signOuts, 1);
    });

    testWidgets('cancelling keeps you signed in', (tester) async {
      final session = await _openSettings(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.signOuts, 0);
    });
  });

  test('the feed does not outlive the account that loaded it', () async {
    final matching = _Matching();
    final session = _Session();
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => session),
        matchingRepositoryProvider.overrideWithValue(matching),
      ],
    );
    addTearDown(container.dispose);
    // Kept alive the way the home screen keeps it.
    container.listen(feedProvider, (_, __) {}, fireImmediately: true);
    await pumpEventQueue();
    expect(container.read(feedProvider).cursor, 1);

    // Signed out: the deck is emptied and nothing is fetched without a token.
    session.become(null);
    await pumpEventQueue();
    expect(container.read(feedProvider).cursor, isNull);
    expect(matching.feeds, 1);

    // The next person gets their own deck.
    session.become('b');
    await pumpEventQueue();
    expect(container.read(feedProvider).cursor, 2);
  });
}
