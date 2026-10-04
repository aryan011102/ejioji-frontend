import 'package:ejioji/shared/widgets/app_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Home's other face is Blind, so the tab says which face is showing.
void main() {
  Widget bar({required bool blind}) => MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppTabBar(
            current: AppTab.home,
            blind: blind,
            onSelect: (_) {},
            onHoldHome: () {},
          ),
        ),
      );

  testWidgets('the tab reads Home until Home is flipped', (tester) async {
    await tester.pumpWidget(bar(blind: false));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Blind'), findsNothing);
  });

  testWidgets('the tab reads Blind while the blind plane shows',
      (tester) async {
    await tester.pumpWidget(bar(blind: true));
    await tester.pumpAndSettle();

    expect(find.text('Blind'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('flipping back puts Home back', (tester) async {
    await tester.pumpWidget(bar(blind: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(bar(blind: false));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Blind'), findsNothing);
  });

  testWidgets('the other two tabs never change', (tester) async {
    await tester.pumpWidget(bar(blind: true));
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });
}
