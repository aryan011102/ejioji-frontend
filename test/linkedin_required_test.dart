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
    expect(publish.needsLinkedIn, isTrue);
  });

  test('with the rule off on the server, LinkedIn is not needed', () {
    // PROFILE_REQUIRES_LINKEDIN=false (App Review, 2026-09-30): the same
    // profile, and the server simply never lists it.
    final publish = PublishState.fromJson({
      'published': true,
      'visible': false,
      'under_review': false,
      'stealth': false,
      'blocking': [
        {'code': 'too_few_photos', 'have': 2, 'need': 3},
      ],
    });
    expect(publish.needsLinkedIn, isFalse);
  });
}
