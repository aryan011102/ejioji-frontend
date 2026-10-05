import 'package:ejioji/core/network/api_exception.dart';
import 'package:ejioji/shared/models/chat.dart';
import 'package:ejioji/shared/models/person.dart';
import 'package:ejioji/shared/models/tile.dart';
import 'package:ejioji/shared/widgets/ask_about_sheet.dart';
import 'package:ejioji/shared/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _quote() => {
      'id': 'q1',
      'owner_id': 'her',
      'kind': 'prompt',
      'category': 'music',
      'quoted_at': '2026-09-27T10:00:00+00:00',
      'removed': false,
      'insight': null,
      'prompt': {'question': 'The song on repeat', 'answer': 'Old Arijit'},
    };

final _tile = ProfileTile.fromJson({
  'kind': 'prompt',
  'key': 'on_repeat',
  'category': 'music',
  'prompt': {
    'prompt_key': 'on_repeat',
    'category': 'music',
    'question': 'The song on repeat',
    'kind': 'text',
    'answer': 'Old Arijit',
    'answered_at': '2026-09-27T10:00:00+00:00',
  },
});

/// A button that opens the sheet, and whatever [send] was handed.
Widget _host(
  Future<String> Function(String) send,
  List<bool?> results, {
  bool verified = true,
  bool replying = false,
  VoidCallback? onVerify,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showAskAboutSheet(
                context,
                name: 'Riya',
                tile: _tile,
                send: send,
                verified: verified,
                replying: replying,
                onVerify: onVerify,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  group('the note', () {
    test('a request carries what was written with its tile', () {
      final r = PendingRequest.fromJson({
        'id': 'r1',
        'requested_at': '2026-09-27T10:00:00+00:00',
        'person': {
          'user_id': 'u',
          'first_name': 'Riya',
          'age': 27,
          'city': 'delhi_ncr',
          'photos': <Object>[],
          'tiles': <Object>[],
        },
        'tile': _quote(),
        'note': 'Same, honestly',
      });
      expect(r.note, 'Same, honestly');
    });

    test('an opener carries it, and an older server without one reads null',
        () {
      final page = MessagePage.fromJson({
        'messages': <Object>[],
        'has_more': false,
        'openers': [
          {'sender_id': 'me', 'tile': _quote(), 'note': 'Good taste'},
          {'sender_id': 'her', 'tile': _quote()},
        ],
      });
      expect([for (final o in page.openers) o.note], ['Good taste', null]);
    });
  });

  group('the ask sheet', () {
    testWidgets('sends what was written, trimmed, and closes', (tester) async {
      final sent = <String>[];
      final results = <bool?>[];
      Future<String> send(String note) async {
        sent.add(note);
        return 'Asked about this.';
      }

      await tester.pumpWidget(_host(send, results));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Good taste  ');
      // Typing has to reach a frame before the button is tappable: it is
      // dimmed while nothing is written.
      await tester.pump();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(sent, ['Good taste']);
      expect(results, [true]);
      expect(find.text('Asked about this.'), findsOneWidget);
    });

    testWidgets('nothing written sends nothing at all', (tester) async {
      final sent = <String>[];
      final results = <bool?>[];
      Future<String> send(String note) async {
        sent.add(note);
        return 'Asked about this.';
      }

      await tester.pumpWidget(_host(send, results));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Send, with an empty field and then with spaces, and neither asks.
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(sent, isEmpty);
      expect(results, isEmpty);
      expect(find.text('Ask Riya about this'), findsOneWidget);
    });

    testWidgets('Send is dimmed until a line is written', (tester) async {
      await tester.pumpWidget(_host((_) async => 'Asked about this.', []));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(Pressable, 'Send request');
      bool live() => tester.widget<Pressable>(button).onTap != null;

      expect(live(), isFalse, reason: 'nothing written');

      await tester.enterText(find.byType(TextField), 'Good taste');
      await tester.pump();
      expect(live(), isTrue, reason: 'a line written');

      await tester.enterText(find.byType(TextField), '  ');
      await tester.pump();
      expect(live(), isFalse, reason: 'spaces are nothing written');
    });

    testWidgets('the keyboard send key does not send an empty line',
        (tester) async {
      final sent = <String>[];
      Future<String> send(String note) async {
        sent.add(note);
        return 'Asked about this.';
      }

      await tester.pumpWidget(_host(send, []));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
    });

    testWidgets('nothing stands under the field until something is refused',
        (tester) async {
      await tester.pumpWidget(_host((_) async => '', []));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sees this with your request'),
        findsNothing,
      );
      expect(find.textContaining('Numbers and handles'), findsNothing);
    });

    testWidgets('a refused line keeps the sheet open on it and says why',
        (tester) async {
      final results = <bool?>[];
      Future<String> send(String note) async {
        throw const ValidationFailure(
          'Keep contact details for after they say yes.',
          code: 'text_rejected',
        );
      }

      await tester.pumpWidget(_host(send, results));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'call 9876543210');
      await tester.pump();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(results, isEmpty);
      expect(find.text('Ask Riya about this'), findsOneWidget);
      expect(
        find.text('Keep contact details for after they say yes.'),
        findsOneWidget,
      );
      expect(find.text('call 9876543210'), findsOneWidget);
    });

    testWidgets('the field stops at 150 characters', (tester) async {
      await tester.pumpWidget(_host((_) async => '', []));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'x' * 200);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, requestNoteMaxChars);
    });
  });

  group('the sheet when the profile is not verified', () {
    /// The line opens the conversation, so sending one needs a tick
    /// (2026-10-05). The sheet still takes what they write; the button goes to
    /// verification instead of sending.
    testWidgets('the button offers verification and sends nothing',
        (tester) async {
      final sent = <String>[];
      var verifying = 0;
      final results = <bool?>[];
      Future<String> send(String note) async {
        sent.add(note);
        return 'Asked about this.';
      }

      await tester.pumpWidget(
        _host(send, results, verified: false, onVerify: () => verifying++),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // They can still type: the sheet is not a wall.
      expect(find.text('Send request'), findsNothing);
      expect(find.text('Verify profile to send'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Good taste');
      await tester.pump();

      await tester.tap(find.text('Verify profile to send'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(verifying, 1);
    });

    testWidgets('it offers verification with the field still empty',
        (tester) async {
      var verifying = 0;
      await tester.pumpWidget(
        _host(
          (_) async => '',
          <bool?>[],
          verified: false,
          onVerify: () => verifying++,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Not dimmed: it is not sending anything, so nothing has to be written.
      await tester.tap(find.text('Verify profile to send'));
      await tester.pumpAndSettle();
      expect(verifying, 1);
    });

    testWidgets("the keyboard's send key does not get past it either",
        (tester) async {
      final sent = <String>[];
      var verifying = 0;
      Future<String> send(String note) async {
        sent.add(note);
        return 'Asked about this.';
      }

      await tester.pumpWidget(
        _host(send, <bool?>[], verified: false, onVerify: () => verifying++),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Good taste');
      await tester.pump();

      // The field's own send action, not the button.
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(verifying, 1);
    });

    testWidgets('answering someone who asked you says reply, not request',
        (tester) async {
      await tester.pumpWidget(
        _host((_) async => '', <bool?>[], verified: false, replying: true),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Verify profile to reply'), findsOneWidget);
      // A bare verb either way, and never the other one's.
      expect(find.text('Verify profile to send reply'), findsNothing);
      expect(find.text('Verify profile to send'), findsNothing);
    });

    testWidgets('verified, a reply still reads as a reply', (tester) async {
      await tester.pumpWidget(
        _host((_) async => 'Asked about this.', <bool?>[], replying: true),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Send reply'), findsOneWidget);
    });

    testWidgets("the server's refusal offers verification too", (tester) async {
      // An older build, or a tick that lapsed since this screen loaded.
      var verifying = 0;
      // Exactly what the client builds from a 403 verification_required.
      Future<String> send(String note) async => throw const ForbiddenFailure(
            code: 'verification_required',
            message: 'Verify your profile to send a line with your request.',
          );

      await tester.pumpWidget(
        _host(send, <bool?>[], onVerify: () => verifying++),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Good taste');
      await tester.pump();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(verifying, 1);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
