import 'package:ejioji/core/native/apple_music_kit.dart';
import 'package:ejioji/data/connect_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dart half of the MusicKit bridge, against a fake of the Swift half.
///
/// The Swift side cannot run here, so what is pinned is the contract between
/// them: the method name, the argument, and what each error code turns into.
/// A code the Swift side sends that Dart misreads would show someone "try
/// again" when only Settings can help, or the other way round.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('theonebytwo/apple_music');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final value = reply(call);
      if (value is PlatformException) throw value;
      return value;
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('the developer token goes to Swift and the user token comes back', () async {
    final calls = <MethodCall>[];
    answer((call) {
      calls.add(call);
      return 'user-token-from-musickit';
    });
    expect(await AppleMusicKit.userToken('dev-token'), 'user-token-from-musickit');
    expect(calls.single.method, 'userToken');
    expect(calls.single.arguments, {'developerToken': 'dev-token'});
  });

  test('saying no now is a decline, not a Settings problem', () async {
    answer((_) => PlatformException(code: 'denied'));
    await expectLater(
      AppleMusicKit.userToken('dev-token'),
      throwsA(isA<AppleMusicDenied>().having((e) => e.inSettings, 'inSettings', false)),
    );
  });

  test('having said no before points at Settings', () async {
    answer((_) => PlatformException(code: 'denied_in_settings'));
    await expectLater(
      AppleMusicKit.userToken('dev-token'),
      throwsA(isA<AppleMusicDenied>().having((e) => e.inSettings, 'inSettings', true)),
    );
  });

  test('anything else is unavailable, with the code kept for logs', () async {
    answer((_) => PlatformException(code: 'token_failed'));
    await expectLater(
      AppleMusicKit.userToken('dev-token'),
      throwsA(isA<AppleMusicUnavailable>().having((e) => e.reason, 'reason', 'token_failed')),
    );
  });

  test('an empty token is not a token', () async {
    answer((_) => '');
    await expectLater(
      AppleMusicKit.userToken('dev-token'),
      throwsA(isA<AppleMusicUnavailable>()),
    );
  });

  test('no Swift half at all is unavailable, not a crash', () async {
    await expectLater(
      AppleMusicKit.userToken('dev-token'),
      throwsA(isA<AppleMusicUnavailable>()),
    );
  });

  test("Apple's reason comes through with the failure", () async {
    answer(
      (_) => PlatformException(
        code: 'token_failed',
        details: 'privacy_acknowledgement',
      ),
    );
    await expectLater(
      AppleMusicKit.userToken('dev-token'),
      throwsA(
        isA<AppleMusicUnavailable>()
            .having((e) => e.detail, 'detail', 'privacy_acknowledgement'),
      ),
    );
  });

  test('MusicKit refusing after the prompt points at Settings', () async {
    answer(
      (_) => PlatformException(code: 'token_failed', details: 'permission_denied'),
    );
    await expectLater(
      AppleMusicKit.userToken('dev-token'),
      throwsA(isA<AppleMusicDenied>().having((e) => e.inSettings, 'inSettings', true)),
    );
  });

  test('each reason gets its own advice, and says which it was', () {
    expect(appleMusicTrouble('privacy_acknowledgement'), contains('Open the Music app'));
    expect(appleMusicTrouble('not_signed_in'), contains('Sign in to Apple Music'));
    expect(appleMusicTrouble('developer_token'), contains('That is on us'));
    for (final reason in ['privacy_acknowledgement', 'not_signed_in', 'user_token']) {
      expect(appleMusicTrouble(reason), endsWith('($reason)'));
    }
    expect(appleMusicTrouble(null), endsWith('(no reason)'));
  });
}
