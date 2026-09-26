import 'package:ejioji/core/push/push.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

/// The payloads in these tests are copied from the backend's notify.py files.
/// Nothing else in the app reads them, and a mistake here is silent: a tapped
/// notification would open the wrong screen, or none, on somebody's phone.
void main() {
  group('what a tapped notification opens', () {
    test('a message opens its conversation, which is keyed by the match', () {
      final open = PushOpen.from(
        const RemoteMessage(data: {'type': 'message', 'match_id': 'm-1'}),
      );
      expect(open?.kind, PushKind.message);
      expect(open?.id, 'm-1');
    });

    test('an accepted request also opens the conversation', () {
      final open = PushOpen.from(
        const RemoteMessage(data: {'type': 'match', 'match_id': 'm-2'}),
      );
      expect(open?.kind, PushKind.match);
      expect(open?.id, 'm-2');
    });

    test('a new request carries the request, not a match', () {
      final open = PushOpen.from(
        const RemoteMessage(data: {'type': 'request', 'request_id': 'r-1'}),
      );
      expect(open?.kind, PushKind.request);
      expect(open?.id, 'r-1');
    });

    test('the daily profile views push opens the list, with no id', () {
      final open = PushOpen.from(
        const RemoteMessage(data: {'type': 'profile_views'}),
      );
      expect(open?.kind, PushKind.profileViews);
      expect(open?.id, isNull);
    });

    test('a kind this build has never heard of is ignored', () {
      // The server can start pushing something new before this app ships.
      // Ignoring it leaves the notification itself readable and opens the app
      // where it was, which is better than guessing a screen.
      expect(
        PushOpen.from(const RemoteMessage(data: {'type': 'something_new'})),
        isNull,
      );
      expect(PushOpen.from(const RemoteMessage()), isNull);
      expect(PushOpen.from(null), isNull);
    });

    test('a known kind with no id is read, and its id is null', () {
      // Worth pinning: the app must not crash on it. The screen it would have
      // opened is skipped instead.
      final open = PushOpen.from(const RemoteMessage(data: {'type': 'message'}));
      expect(open?.kind, PushKind.message);
      expect(open?.id, isNull);
    });
  });
}
