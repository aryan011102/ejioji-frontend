import 'package:ejioji/core/session/session.dart';
import 'package:ejioji/features/auth/presentation/splash_page.dart';
import 'package:ejioji/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Signed out and settled, so the first screen's buttons are showing.
class _SignedOut extends SessionController {
  @override
  Session build() => const Session(stage: SessionStage.signedOut);
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(_SignedOut.new)],
      child: const MaterialApp(home: SplashPage()),
    ),
  );
  await tester.pumpAndSettle();
}

bool _canStart(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed != null;

void main() {
  testWidgets('nobody gets past the first screen without ticking the terms',
      (tester) async {
    await _open(tester);
    // Never pre-ticked.
    expect(_canStart(tester), isFalse);
    expect(
      tester.widget<TextActionButton>(find.byType(TextActionButton)).onPressed,
      isNull,
    );

    await tester.tap(find.textContaining('I am 18 or over'));
    await tester.pumpAndSettle();
    expect(_canStart(tester), isTrue);

    // And taking the tick back closes the way again.
    await tester.tap(find.textContaining('I am 18 or over'));
    await tester.pumpAndSettle();
    expect(_canStart(tester), isFalse);
  });

  testWidgets('the tick names both documents', (tester) async {
    await _open(tester);
    final label = find
        .descendant(of: find.byType(Row), matching: find.byType(RichText))
        .first;
    final text = tester.widget<RichText>(label).text.toPlainText();
    expect(text, contains('Terms'));
    expect(text, contains('Privacy Policy'));
    expect(text, contains('18 or over'));
    expect(text, contains('consent'));
  });
}
