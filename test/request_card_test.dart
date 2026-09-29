import 'package:ejioji/data/providers.dart';
import 'package:ejioji/features/chats/presentation/chats_page.dart';
import 'package:ejioji/shared/models/chat.dart';
import 'package:ejioji/shared/models/enums.dart';
import 'package:ejioji/shared/models/person.dart';
import 'package:ejioji/shared/widgets/fact_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PendingRequest _request({Map<String, Object?>? tile}) =>
    PendingRequest.fromJson({
      'id': 'r1',
      'requested_at': DateTime.now()
          .subtract(const Duration(minutes: 20))
          .toUtc()
          .toIso8601String(),
      'person': {
        'user_id': 'u',
        'first_name': 'Riya',
        'last_name': 'Sen',
        'age': 27,
        'city': 'delhi_ncr',
        'languages': ['hindi', 'english'],
        'education': 'masters',
        'company': 'Zeta',
        'drinking': 'socially',
        'photos': <Object>[],
        'tiles': [
          {
            'kind': 'prompt',
            'key': 'on_repeat',
            'category': 'music',
            'prompt': {
              'prompt_key': 'on_repeat',
              'category': 'music',
              'question': 'The song on repeat',
              'kind': 'text',
              'answer': 'Old Arijit',
              'answered_at': '2026-09-27T10:00:00+00:00',
            },
          },
        ],
      },
      if (tile != null) 'tile': tile,
    });

Future<void> _openRequests(WidgetTester tester, PendingRequest r) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((_) async => <Conversation>[]),
        incomingRequestsProvider.overrideWith((_) async => [r]),
      ],
      child: const MaterialApp(home: ChatsPage()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Requests (1)'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a request card shows the facts row, not a tile', (tester) async {
    await _openRequests(tester, _request());

    final row = find.byType(FactChipRow);
    expect(row, findsOneWidget);
    for (final label in [
      City.delhiNcr.label,
      '27',
      'Zeta',
      'Hindi, English',
      "Master's",
      'Drinks socially',
    ]) {
      // The row scrolls sideways, and builds a chip only once it is in view.
      await tester.scrollUntilVisible(
        find.descendant(of: row, matching: find.text(label)),
        60,
        scrollable:
            find.descendant(of: row, matching: find.byType(Scrollable)),
      );
      expect(
        find.descendant(of: row, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    // Age is a chip now, so the title is the name alone.
    expect(find.text('Riya Sen'), findsOneWidget);
    expect(find.text('Asked 20m ago'), findsOneWidget);

    // Their first tile used to stand in here.
    expect(find.textContaining('The song on repeat'), findsNothing);
    expect(find.textContaining('Old Arijit'), findsNothing);
  });

  testWidgets('a request about a tile still shows that tile under the row',
      (tester) async {
    await _openRequests(
      tester,
      _request(
        tile: {
          'id': 'q1',
          'owner_id': 'me',
          'kind': 'prompt',
          'category': 'music',
          'quoted_at': '2026-09-27T10:00:00+00:00',
          'removed': false,
          'insight': null,
          'prompt': {'question': 'Sunday 11am', 'answer': 'Still asleep'},
        },
      ),
    );

    expect(find.byType(FactChipRow), findsOneWidget);
    expect(find.text('Riya wants to chat about this'), findsOneWidget);
    expect(find.textContaining('Still asleep'), findsOneWidget);
  });
}
