import 'dart:async';

import 'package:ejioji/app/in_app_banner.dart';
import 'package:ejioji/core/push/push.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PushShown message(String matchId, String text) => PushShown(
      open: PushOpen(kind: PushKind.message, id: matchId),
      title: 'Priya',
      body: text,
    );

void main() {
  group('what a push that arrives while the app is open says', () {
    test('a message push is read with its title and text', () {
      final shown = PushShown.from(
        const RemoteMessage(
          data: {'type': 'message', 'match_id': 'm-1'},
          notification: RemoteNotification(title: 'Priya', body: 'Free Sunday?'),
        ),
      );
      expect(shown?.open.kind, PushKind.message);
      expect(shown?.open.id, 'm-1');
      expect(shown?.title, 'Priya');
      expect(shown?.body, 'Free Sunday?');
    });

    test('a push with nothing to say, or of an unknown kind, is dropped', () {
      expect(
        PushShown.from(
          const RemoteMessage(data: {'type': 'message', 'match_id': 'm-1'}),
        ),
        isNull,
      );
      expect(
        PushShown.from(
          const RemoteMessage(
            data: {'type': 'profile_view'},
            notification: RemoteNotification(title: 'Priya', body: 'hi'),
          ),
        ),
        isNull,
      );
    });
  });

  group('the conversation on screen', () {
    tearDown(() {
      while (OpenConversations.top != null) {
        OpenConversations.closed(OpenConversations.top!);
      }
    });

    test('is the one opened last, and the one below comes back', () {
      OpenConversations.opened('m-1');
      OpenConversations.opened('m-2');
      expect(OpenConversations.top, 'm-2');
      OpenConversations.closed('m-2');
      expect(OpenConversations.top, 'm-1');
      OpenConversations.closed('m-1');
      expect(OpenConversations.top, isNull);
    });
  });

  group('the banner', () {
    late StreamController<PushShown> arrivals;
    late List<PushOpen> tapped;

    Future<void> pump(
      WidgetTester tester, {
      bool Function(PushShown)? shouldShow,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InAppBanner(
            arrivals: arrivals.stream,
            shouldShow: shouldShow ?? (_) => true,
            onTap: tapped.add,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
    }

    setUp(() {
      arrivals = StreamController<PushShown>();
      tapped = [];
    });

    tearDown(() => arrivals.close());

    testWidgets('shows the name and the text, then goes by itself',
        (tester) async {
      await pump(tester);
      arrivals.add(message('m-1', 'Free Sunday?'));
      await tester.pumpAndSettle();
      expect(find.text('Priya'), findsOneWidget);
      expect(find.text('Free Sunday?'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Free Sunday?'), findsNothing);
    });

    testWidgets('is not shown when the app says not to', (tester) async {
      // The app says not to for the conversation already on screen.
      await pump(tester, shouldShow: (s) => s.open.id != 'm-1');
      arrivals.add(message('m-1', 'You are reading this already'));
      await tester.pumpAndSettle();
      expect(find.text('You are reading this already'), findsNothing);

      arrivals.add(message('m-2', 'Someone else'));
      await tester.pumpAndSettle();
      expect(find.text('Someone else'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a newer push replaces the one showing', (tester) async {
      await pump(tester);
      arrivals.add(message('m-1', 'first'));
      await tester.pumpAndSettle();
      arrivals.add(message('m-1', 'second'));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a tap opens what it was about and dismisses it',
        (tester) async {
      await pump(tester);
      arrivals.add(message('m-3', 'tap me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('tap me'));
      await tester.pumpAndSettle();
      expect(tapped.single.id, 'm-3');
      expect(find.text('tap me'), findsNothing);
    });
  });
}
