import 'package:ejioji/core/network/api_exception.dart';
import 'package:ejioji/data/providers.dart';
import 'package:ejioji/data/support_repository.dart';
import 'package:ejioji/features/account/presentation/report_problem_page.dart';
import 'package:ejioji/features/account/presentation/support_page.dart';
import 'package:ejioji/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeSupport implements SupportRepository {
  _FakeSupport({this.fail});

  final ApiException? fail;
  final sent = <(FeedbackTopic, String, String?)>[];

  @override
  Future<String> sendFeedback({
    required FeedbackTopic topic,
    required String message,
    String? appVersion,
  }) async {
    if (fail != null) throw fail!;
    sent.add((topic, message, appVersion));
    return 'f-1';
  }
}

/// The form behind a home screen, so sending can pop back to it.
Future<void> _pumpForm(WidgetTester tester, _FakeSupport fake) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('home')),
      GoRoute(path: '/problem', builder: (_, __) => const ReportProblemPage()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supportRepositoryProvider.overrideWithValue(fake),
        appVersionProvider.overrideWith((ref) async => '1.0.3 (42)'),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/problem');
  await tester.pumpAndSettle();
}

bool _sendEnabled(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed != null;

void main() {
  group('report a problem', () {
    testWidgets('nothing goes until something is written, then it goes with '
        'the topic picked and returns', (tester) async {
      final fake = _FakeSupport();
      await _pumpForm(tester, fake);
      expect(_sendEnabled(tester), isFalse);

      await tester.tap(find.text('An idea'));
      await tester.enterText(find.byType(TextField), 'Let me pin a tile');
      await tester.pumpAndSettle();
      expect(_sendEnabled(tester), isTrue);

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(fake.sent, [(FeedbackTopic.idea, 'Let me pin a tile', '1.0.3 (42)')]);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('only spaces is not something to send', (tester) async {
      await _pumpForm(tester, _FakeSupport());
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(_sendEnabled(tester), isFalse);
    });

    testWidgets('a refusal says why and keeps what was written', (tester) async {
      final fake = _FakeSupport(
        fail: const RateLimitedFailure(
          message: 'We have your messages for today. Write again tomorrow.',
        ),
      );
      await _pumpForm(tester, fake);
      await tester.enterText(find.byType(TextField), 'It crashed');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(
        find.text('We have your messages for today. Write again tomorrow.'),
        findsOneWidget,
      );
      expect(find.text('It crashed'), findsOneWidget);
      expect(find.text('home'), findsNothing);
    });
  });

  group('the version sent', () {
    test('a build string goes as it is', () {
      expect(sendableVersion(' 1.0.3 (42) '), '1.0.3 (42)');
      expect(sendableVersion('0.1.0'), '0.1.0');
    });

    test('anything the server would refuse is left off, not sent', () {
      expect(sendableVersion(null), isNull);
      expect(sendableVersion(''), isNull);
      expect(sendableVersion('1.0 <beta>'), isNull);
      expect(sendableVersion('1.0.0-${'x' * 40}'), isNull);
    });
  });

  testWidgets('support has no download or delete row', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SupportPage())),
    );
    expect(find.textContaining('Download'), findsNothing);
    expect(find.text('Report a problem'), findsOneWidget);
    expect(find.text('Safety tips'), findsOneWidget);
  });
}
