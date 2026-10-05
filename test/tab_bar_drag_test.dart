import 'package:ejioji/core/theme/platform.dart';
import 'package:ejioji/shared/widgets/app_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// On the floating bar the lens can be dragged to another tab, and the drag
/// must not take tapping or holding Home away.
void main() {
  setUp(() => AppPlatform.debugOverrideAndroid = false);
  tearDown(() => AppPlatform.debugOverrideAndroid = null);

  late List<AppTab> selected;
  late int holds;

  Widget bar({AppTab current = AppTab.home}) => MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppTabBar(
            current: current,
            onSelect: selected.add,
            onHoldHome: () => holds++,
          ),
        ),
      );

  setUp(() {
    selected = [];
    holds = 0;
  });

  testWidgets('dragging the lens from Home to You opens You', (tester) async {
    await tester.pumpWidget(bar());
    await tester.pumpAndSettle();

    final from = tester.getCenter(find.text('Home'));
    final to = tester.getCenter(find.text('You'));
    await tester.dragFrom(from, Offset(to.dx - from.dx, 0));
    await tester.pumpAndSettle();

    expect(selected, [AppTab.you]);
  });

  testWidgets('a drag that ends back on the current tab opens nothing',
      (tester) async {
    await tester.pumpWidget(bar(current: AppTab.chats));
    await tester.pumpAndSettle();

    final chats = tester.getCenter(find.text('Chats'));
    final gesture = await tester.startGesture(chats);
    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(-60, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selected, isEmpty);
  });

  testWidgets('a drag past the end lands on the last tab', (tester) async {
    await tester.pumpWidget(bar());
    await tester.pumpAndSettle();

    await tester.dragFrom(
      tester.getCenter(find.text('Home')),
      const Offset(2000, 0),
    );
    await tester.pumpAndSettle();

    expect(selected, [AppTab.you]);
  });

  testWidgets('a tap still opens a tab', (tester) async {
    await tester.pumpWidget(bar());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();

    expect(selected, [AppTab.chats]);
  });

  testWidgets('holding Home still turns it over', (tester) async {
    await tester.pumpWidget(bar());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Home'));
    await tester.pumpAndSettle();

    expect(holds, 1);
    expect(selected, isEmpty);
  });
}
