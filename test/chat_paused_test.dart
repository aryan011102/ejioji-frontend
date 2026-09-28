import 'package:ejioji/shared/models/chat.dart';
import 'package:flutter_test/flutter_test.dart';

/// A conversation the server has paused (a photo in it was refused as sexual,
/// and a moderator has not looked yet) says so on every page of messages.
void main() {
  Map<String, Object?> page({Object? paused}) => {
        'messages': <Object?>[],
        'openers': <Object?>[],
        'has_more': false,
        'my_read_seq': 0,
        'their_read_seq': 0,
        if (paused != null) 'paused': paused,
      };

  test('a paused conversation reads as paused', () {
    expect(MessagePage.fromJson(page(paused: true)).paused, isTrue);
  });

  test('an older server that never says is not paused', () {
    expect(MessagePage.fromJson(page()).paused, isFalse);
    expect(MessagePage.fromJson(page(paused: false)).paused, isFalse);
  });
}
