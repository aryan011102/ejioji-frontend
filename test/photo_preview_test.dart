import 'dart:typed_data';

import 'package:ejioji/features/chats/presentation/photo_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A photo picked for a chat is shown before it goes, and only send sends it.
void main() {
  // A 1x1 transparent PNG.
  final png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  Future<List<bool>> open(WidgetTester tester, {String? name}) async {
    final answers = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers
                .add(await confirmPhoto(context, bytes: png, name: name)),
            child: const Text('pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    return answers;
  }

  testWidgets('the photo shows before anything is sent', (tester) async {
    final answers = await open(tester, name: 'Priya');
    expect(find.byType(PhotoPreview), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('To Priya'), findsOneWidget);
    expect(answers, isEmpty);
  });

  testWidgets('send sends', (tester) async {
    final answers = await open(tester);
    await tester.tap(find.byKey(PhotoPreview.sendKey));
    await tester.pumpAndSettle();
    expect(answers, [true]);
    expect(find.byType(PhotoPreview), findsNothing);
  });

  testWidgets('closing sends nothing', (tester) async {
    final answers = await open(tester);
    await tester.tap(find.byKey(PhotoPreview.closeKey));
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });

  testWidgets('going back sends nothing', (tester) async {
    final answers = await open(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });
}
