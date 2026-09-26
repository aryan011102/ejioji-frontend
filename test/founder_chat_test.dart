import 'package:ejioji/shared/models/chat.dart';
import 'package:flutter_test/flutter_test.dart';

/// The conversation shape from the backend's chat/schemas.py ConversationOut.
Map<String, Object?> conversation({Object? founderLine}) => {
      'match_id': 'm-1',
      'matched_at': '2026-09-27T10:00:00+00:00',
      'person': {'user_id': 'u-1', 'first_name': 'Pritika', 'photo': null},
      'last_message': null,
      'unread': 0,
      'their_read_seq': 0,
      if (founderLine != null) 'founder_line': founderLine,
    };

void main() {
  test('a founder conversation says so, and opens no profile', () {
    expect(Conversation.fromJson(conversation(founderLine: true)).founderLine, isTrue);
  });

  test('an ordinary match, or an older server, is not one', () {
    expect(Conversation.fromJson(conversation(founderLine: false)).founderLine, isFalse);
    expect(Conversation.fromJson(conversation()).founderLine, isFalse);
  });
}
