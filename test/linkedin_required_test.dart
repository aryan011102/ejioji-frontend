import 'package:ejioji/shared/models/enums.dart';
import 'package:ejioji/shared/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nobody is shown without a LinkedIn link (backend decision log,
/// 2026-09-29). The server lists it with everything else still missing.
void main() {
  test('the server naming LinkedIn is read as LinkedIn missing', () {
    final publish = PublishState.fromJson({
      'published': true,
      'visible': false,
      'under_review': false,
      'stealth': false,
      'blocking': [
        {'code': 'no_linkedin', 'have': 0, 'need': 1},
      ],
    });
    expect(publish.visible, isFalse);
    expect(publish.blocking.single.code, Blocker.noLinkedin);
    expect(publish.blocking.single.message, 'Add your LinkedIn profile link');
  });
}
