import 'package:ejioji/features/chats/presentation/unmatch_reason_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Why someone is unmatching (backend decision log, 2026-09-29). The keys are
/// the server's; one it does not know is a 422 and the unmatch does not happen.
void main() {
  test('the keys are the ones the server stores', () {
    expect(UnmatchReason.values.map((r) => r.key).toList(), [
      'different_things',
      'no_spark',
      'went_quiet',
      'met_someone',
      'not_genuine',
      'disrespectful',
      'other',
    ]);
  });

  test('only the two a moderator should see offer a report', () {
    expect(
      UnmatchReason.values.where((r) => r.safety).toList(),
      [UnmatchReason.notGenuine, UnmatchReason.disrespectful],
    );
  });

  Future<List<Object?>> tap(WidgetTester tester, String label) async {
    final got = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnmatchReasonCard(
            name: 'Meera',
            onAnswer: (a) => got.add(a.reason),
            onCancel: () => got.add('cancel'),
          ),
        ),
      ),
    );
    await tester.tap(find.text(label));
    return got;
  }

  testWidgets('picking a reason is the answer', (tester) async {
    expect(await tap(tester, "We didn't click"), [UnmatchReason.noSpark]);
    expect(find.textContaining('Meera is never told'), findsOneWidget);
  });

  testWidgets('rather not say unmatches without a reason', (tester) async {
    expect(await tap(tester, 'Rather not say'), [null]);
  });

  testWidgets('cancel is not an answer', (tester) async {
    expect(await tap(tester, 'Cancel'), ['cancel']);
  });
}
