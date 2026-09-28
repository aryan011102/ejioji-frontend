import 'package:ejioji/core/native/screen_capture.dart';
import 'package:ejioji/shared/widgets/capture_shield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dart half of screenshot protection, against a fake of the native half.
///
/// The Swift and Kotlin halves cannot run here, so what is pinned is the
/// contract: protection goes on with the first protected screen and off with
/// the last, a recording covers the screen, and a screenshot tells the taker.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('theonebytwo/screen_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<bool> sent;
  var recording = false;

  setUp(() {
    ScreenCapture.reset();
    sent = [];
    recording = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent.add(call.arguments as bool);
      return recording;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    ScreenCapture.reset();
  });

  /// What the native half sends Dart: a screenshot, or a recording starting.
  Future<void> fromNative(String method, [Object? arguments]) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }

  Widget app(Widget home) => MaterialApp(home: Scaffold(body: home));

  testWidgets('on with the first shield, off with the last, nothing between',
      (tester) async {
    final both = ValueNotifier(2);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<int>(
          valueListenable: both,
          builder: (_, n, __) => Column(
            children: [
              for (var i = 0; i < n; i++)
                const CaptureShield(child: SizedBox(height: 10)),
            ],
          ),
        ),
      ),
    );
    expect(sent, [true]);
    expect(ScreenCapture.holds, 2);

    both.value = 1;
    await tester.pump();
    expect(sent, [true], reason: 'one shield still up');

    both.value = 0;
    await tester.pump();
    expect(sent, [true, false]);
    expect(ScreenCapture.holds, 0);
  });

  testWidgets('moving to the next card never drops protection', (tester) async {
    // The feed swaps one keyed profile for the next.
    await tester.pumpWidget(
      app(const CaptureShield(key: ValueKey('a'), child: Text('Asha'))),
    );
    await tester.pumpWidget(
      app(const CaptureShield(key: ValueKey('b'), child: Text('Bela'))),
    );
    expect(sent, [true]);
    expect(ScreenCapture.holds, 1);
  });

  testWidgets('a screenshot tells whoever took it', (tester) async {
    await tester.pumpWidget(app(const CaptureShield(child: Text('Asha'))));
    await tester.pump();
    await fromNative('screenshot');
    await tester.pump();
    expect(find.text(CaptureShield.screenshotNote), findsOneWidget);
  });

  testWidgets('a screenshot anywhere else says nothing', (tester) async {
    await tester.pumpWidget(app(const CaptureShield(child: Text('Asha'))));
    await tester.pumpWidget(app(const Text('Your own profile')));
    await tester.pump();
    await fromNative('screenshot');
    await tester.pump();
    expect(find.text(CaptureShield.screenshotNote), findsNothing);
  });

  testWidgets('a recording covers the screen, and stopping it uncovers',
      (tester) async {
    await tester.pumpWidget(app(const CaptureShield(child: Text('Asha'))));
    await tester.pump();
    expect(find.text(CaptureShield.recordingNote), findsNothing);

    await fromNative('captured', true);
    await tester.pump();
    expect(find.text(CaptureShield.recordingNote), findsOneWidget);

    await fromNative('captured', false);
    await tester.pump();
    expect(find.text(CaptureShield.recordingNote), findsNothing);
  });

  testWidgets('a screen opened mid-recording is covered at once',
      (tester) async {
    recording = true;
    await tester.pumpWidget(app(const CaptureShield(child: Text('Asha'))));
    await tester.pump();
    expect(find.text(CaptureShield.recordingNote), findsOneWidget);
  });

  testWidgets('no native half is no protection, not a broken screen',
      (tester) async {
    messenger.setMockMethodCallHandler(channel, null);
    await tester.pumpWidget(app(const CaptureShield(child: Text('Asha'))));
    await tester.pump();
    expect(find.text('Asha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
