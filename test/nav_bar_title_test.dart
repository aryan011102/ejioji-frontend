import 'package:ejioji/shared/widgets/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A long name at the top of a chat ends in dots on one line, whether the title
/// opens the profile or not, and never overflows the bar.
void main() {
  const name = 'Priyamvada Chandrasekharan Venkataraman';

  Future<void> pump(WidgetTester tester, {required bool tappable}) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppNavBar(
            title: name,
            titleLeading: const SizedBox(width: 32, height: 32),
            onTitle: tappable ? () {} : null,
            backLabel: 'Chats',
            onBack: () {},
            trailingLabel: '···',
            onTrailing: () {},
          ),
        ),
      ),
    );
  }

  for (final tappable in [true, false]) {
    testWidgets(
        'a long name is cut with dots (${tappable ? 'opens the profile' : 'plain'})',
        (tester) async {
      await pump(tester, tappable: tappable);
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(name));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(tester.getSize(find.text(name)).height, lessThan(30));
    });
  }
}
