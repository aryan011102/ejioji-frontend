import 'package:ejioji/core/network/api_exception.dart';
import 'package:ejioji/core/push/push.dart';
import 'package:ejioji/core/session/session.dart';
import 'package:ejioji/data/providers.dart';
import 'package:ejioji/features/account/presentation/account_page.dart';
import 'package:ejioji/features/home/presentation/waitlisted.dart';
import 'package:ejioji/shared/models/profile.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's waitlist: a new profile waits for the team to take it live. The
/// payloads here are the backend's (profile schemas' PublishOut, admin
/// service.approved).

Map<String, Object?> _publish({bool waitlisted = false}) => {
      'published': true,
      'visible': !waitlisted,
      'blocking': <Object>[],
      'under_review': false,
      'stealth': false,
      'waitlisted': waitlisted,
    };

MyProfile _me({required bool waitlisted}) => MyProfile.fromJson({
      'profile': {
        'first_name': 'Pritika',
        'last_name': 'Rao',
        'birth_date': '1999-04-02',
        'age': 27,
        'gender': 'woman',
        'city': 'delhi_ncr',
      },
      'photos': <Object>[],
      'tiles': <Object>[],
      'publish': _publish(waitlisted: waitlisted),
      'verified': false,
    });

/// A signed-in session holding this publish state, without a stored token.
class _Session extends SessionController {
  _Session(this.publish);

  final PublishState publish;

  @override
  Session build() => Session(stage: SessionStage.ready, publish: publish);
}

Future<void> _openYou(WidgetTester tester, {required bool waitlisted}) async {
  final me = _me(waitlisted: waitlisted);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _Session(me.publish)),
        myProfileProvider.overrideWith((_) async => me),
      ],
      child: const MaterialApp(home: AccountPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the state', () {
    test('waitlisted is read from the publish state', () {
      final waiting = PublishState.fromJson(_publish(waitlisted: true));
      expect(waiting.waitlisted, isTrue);
      expect(waiting.visible, isFalse);
      expect(Session(publish: waiting).isWaitlisted, isTrue);
    });

    test('a server without the waitlist reads as live', () {
      final old = PublishState.fromJson(
        {'published': true, 'visible': true, 'blocking': <Object>[]},
      );
      expect(old.waitlisted, isFalse);
      expect(const Session().isWaitlisted, isFalse);
    });

    test("the feed's refusal is recognised, and nothing else is", () {
      expect(isWaitlistedError(const ForbiddenFailure(code: 'waitlisted')),
          isTrue);
      expect(
        isWaitlistedError(const ForbiddenFailure(code: 'consent_required')),
        isFalse,
      );
      expect(isWaitlistedError(null), isFalse);
    });
  });

  test('"Your profile is live" opens Home, with no id', () {
    final open = PushOpen.from(
      const RemoteMessage(data: {'type': 'approved'}),
    );
    expect(open?.kind, PushKind.approved);
    expect(open?.id, isNull);
  });

  group('screens', () {
    testWidgets('Home says it is waitlisted, how long, and what helps',
        (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WaitlistedScreen(onCompleteProfile: () => completed++),
        ),
      );
      expect(find.text('Your profile is waitlisted'), findsOneWidget);
      expect(
        find.text('Approval can take 24–48 hours. Till then, look around.'),
        findsOneWidget,
      );
      expect(
          find.textContaining('completing your profile helps'), findsOneWidget);
      await tester.tap(find.text('Complete my profile'));
      expect(completed, 1);
    });

    testWidgets('a list of people says profiles open once approved',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfilesOpenLater())),
      );
      expect(find.text('Profiles open once you are approved'), findsOneWidget);
    });

    testWidgets('the You tab says so while waiting', (tester) async {
      await _openYou(tester, waitlisted: true);
      expect(
        find.textContaining('Your profile is waitlisted, approval can take'),
        findsOneWidget,
      );
    });

    testWidgets('and not once live', (tester) async {
      await _openYou(tester, waitlisted: false);
      expect(find.textContaining('waitlisted'), findsNothing);
    });
  });
}
