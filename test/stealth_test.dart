import 'package:ejioji/shared/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _publish({bool? stealth}) => {
      'published': true,
      'visible': true,
      'blocking': <Object>[],
      'under_review': false,
      if (stealth != null) 'stealth': stealth,
    };

void main() {
  test('stealth is read from the publish state, and leaves visible alone', () {
    final state = PublishState.fromJson(_publish(stealth: true));
    expect(state.stealth, isTrue);
    // Whoever they ask still sees the profile.
    expect(state.visible, isTrue);
  });

  test('a server that does not send stealth reads as off', () {
    expect(PublishState.fromJson(_publish()).stealth, isFalse);
  });
}
