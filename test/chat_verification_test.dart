import 'package:ejioji/features/chats/presentation/verify_to_chat.dart';
import 'package:ejioji/shared/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writing in a chat needs a verified profile (backend decision log,
/// 2026-09-29). The server says so on every page of messages, and the app
/// explains it in a popup rather than leaving a keyboard that cannot send.
void main() {
  Map<String, Object?> page({Object? required}) => {
        'messages': <Object?>[],
        'openers': <Object?>[],
        'has_more': false,
        'my_read_seq': 0,
        'their_read_seq': 0,
        if (required != null) 'verification_required': required,
      };

  test('a chat you cannot write in yet says so', () {
    expect(
      MessagePage.fromJson(page(required: true)).verificationRequired,
      isTrue,
    );
  });

  test('an older server that never says lets you write', () {
    expect(MessagePage.fromJson(page()).verificationRequired, isFalse);
    expect(
      MessagePage.fromJson(page(required: false)).verificationRequired,
      isFalse,
    );
  });

  Future<List<String>> tapIn(WidgetTester tester, String label) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerifyToChatCard(
            name: 'Meera',
            onVerify: () => taps.add('verify'),
            onLater: () => taps.add('later'),
          ),
        ),
      ),
    );
    await tester.tap(find.text(label));
    return taps;
  }

  testWidgets('the popup names who they want to talk to', (tester) async {
    await tapIn(tester, 'Verify now');
    expect(find.text('Verify to chat with Meera'), findsOneWidget);
    expect(find.textContaining('still read'), findsOneWidget);
  });

  testWidgets('verify now and not now are two answers', (tester) async {
    expect(await tapIn(tester, 'Verify now'), ['verify']);
    expect(await tapIn(tester, 'Not now'), ['later']);
  });

  testWidgets('the bar in place of the keyboard opens verifying', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VerifyToChatBar(onVerify: () => opened++)),
      ),
    );
    expect(find.text('Verify your profile to send messages.'), findsOneWidget);
    await tester.tap(find.text('Verify'));
    expect(opened, 1);
  });
}
