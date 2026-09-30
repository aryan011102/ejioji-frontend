import 'package:ejioji/features/onboarding/presentation/ai_consent_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The AI question (App Review 5.1.2(i), 2026-09-30): it has to say which AI,
/// and saying no has to be as easy as saying yes.
void main() {
  Future<List<String>> tapped(WidgetTester tester, String label) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiConsentCard(
              onAllow: () => taps.add('allow'),
              onNotNow: () => taps.add('not now'),
              onReadNotice: () => taps.add('notice'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(label));
    return taps;
  }

  testWidgets('names the AI and who makes it', (tester) async {
    await tapped(tester, 'Allow');
    expect(find.textContaining('Claude, an AI made by Anthropic'), findsOneWidget);
    expect(find.textContaining('Saying no is fine'), findsOneWidget);
  });

  testWidgets('each answer is its own tap', (tester) async {
    expect(await tapped(tester, 'Allow'), ['allow']);
    expect(await tapped(tester, 'Not now'), ['not now']);
    expect(await tapped(tester, 'Read the full notice'), ['notice']);
  });
}
