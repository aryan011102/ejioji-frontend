import 'package:ejioji/features/chats/presentation/chat_limit.dart';
import 'package:ejioji/shared/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// At most eight open chats (backend decision log, 2026-10-10). A match past
/// them is listed as locked, and tapping it explains rather than opening.
void main() {
  Map<String, Object?> row({bool? locked}) => {
        'match_id': 'm-9',
        'matched_at': '2026-10-10T10:00:00+00:00',
        'person': {'user_id': 'u-9', 'first_name': 'Priya'},
        'last_message': null,
        'unread': 1,
        'their_read_seq': 0,
        'founder_line': false,
        if (locked != null) 'locked': locked,
      };

  test('the server marking a chat locked is read as locked', () {
    expect(Conversation.fromJson(row(locked: true)).locked, isTrue);
    expect(Conversation.fromJson(row(locked: false)).locked, isFalse);
  });

  test('an older server that never says is read as open', () {
    expect(Conversation.fromJson(row()).locked, isFalse);
  });

  testWidgets('the popup says how many, who is waiting, and what to do',
      (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatLimitCard(name: 'Priya', onDone: () => done++),
        ),
      ),
    );
    expect(find.text('You already have 8 open chats'), findsOneWidget);
    expect(
      find.text('To chat with Priya, unmatch one of them first.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Got it'));
    expect(done, 1);
  });
}
