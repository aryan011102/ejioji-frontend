import 'package:ejioji/data/sharing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a share state reads both readies and the links', () {
    final state = ShareState.fromJson({
      'match_id': 'm1',
      'me_ready': true,
      'them_ready': true,
      'can_share': true,
      'links': [
        {
          'id': 'l1',
          'audience': 'family',
          'created_at': '2026-09-23T10:00:00Z',
          'expires_at': '2026-09-25T10:00:00Z',
        },
      ],
    });
    expect(state.canShare, isTrue);
    expect(state.links.single.audience, ShareAudience.family);
    expect(
      state.links.single.expiresAt.isAtSameMomentAs(DateTime.utc(2026, 9, 25, 10)),
      isTrue,
    );
  });

  test('nobody can share until both are ready', () {
    final state = ShareState.fromJson({
      'me_ready': true,
      'them_ready': false,
      'links': <Object>[],
    });
    expect(state.canShare, isFalse);
  });

  test('an audience the app does not know reads as friends, the narrower one', () {
    expect(ShareAudience.parse('grandparents'), ShareAudience.friends);
  });
}
