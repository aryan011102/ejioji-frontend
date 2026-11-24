import 'package:ejioji/core/network/api_exception.dart';
import 'package:ejioji/features/chats/presentation/games/game_sheets.dart';
import 'package:ejioji/shared/models/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Your own film in guess the movie: the title first, then emoji clues
/// suggested for it, which fill the clue field and stay editable.
void main() {
  late List<String> asked;
  late Future<List<String>> Function(String title) answer;

  Future<List<String>> suggest(String title) {
    asked.add(title);
    return answer(title);
  }

  setUp(() {
    asked = [];
    answer = (_) async => const ['🦁👑🌅', '🦁🐗🐒', '🌍🦁👑'];
  });

  /// Opens the sheet. What it returns gives what the sheet closed with, once
  /// it has.
  Future<Future<OwnCard?> Function()> open(
    WidgetTester tester, {
    bool withSuggestions = true,
  }) async {
    late Future<OwnCard?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showOwnCardSheet(
                context,
                game: GameKind.guessMovie,
                suggestClues: withSuggestions ? suggest : null,
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    return () => result;
  }

  Finder field(String hint) => find.widgetWithText(TextField, hint);

  Future<void> typeTitle(WidgetTester tester, String title) async {
    await tester.enterText(field('The film’s name'), title);
    await tester.pump();
  }

  String clueField(WidgetTester tester) => tester
      .widget<TextField>(find.byType(TextField).last)
      .controller!
      .text;

  testWidgets('the title comes first, and Suggest waits for one',
      (tester) async {
    await open(tester);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.decoration!.hintText, 'The film’s name');
    expect(fields.first.autofocus, isTrue);

    await tester.tap(find.text('Suggest emoji'));
    await tester.pump();
    expect(asked, isEmpty);
  });

  testWidgets('suggested clues fill an empty clue field with the easiest',
      (tester) async {
    final result = await open(tester);
    await typeTitle(tester, 'The Lion King ');
    await tester.tap(find.text('Suggest emoji'));
    await tester.pumpAndSettle();

    expect(asked, ['The Lion King']);
    expect(clueField(tester), '🦁👑🌅');
    // The others are a tap away, and asking again would only repeat them.
    expect(find.text('🦁🐗🐒'), findsOneWidget);
    expect(find.text('Suggest emoji'), findsNothing);

    await tester.tap(find.text('🦁🐗🐒'));
    await tester.pump();
    expect(clueField(tester), '🦁🐗🐒');

    await tester.tap(find.text('Use this'));
    await tester.pumpAndSettle();
    final own = await result();
    expect(own!.text, '🦁🐗🐒');
    expect(own.options, ['The Lion King']);
  });

  testWidgets('a clue already written is kept', (tester) async {
    await open(tester);
    await typeTitle(tester, 'Sholay');
    await tester.enterText(field('Emoji clue, like 🦁👑🌅'), '🐎🔫');
    await tester.pump();
    await tester.tap(find.text('Suggest emoji'));
    await tester.pumpAndSettle();
    expect(clueField(tester), '🐎🔫');
    expect(find.text('🦁👑🌅'), findsOneWidget);
  });

  testWidgets('a new title clears the old one’s clues', (tester) async {
    await open(tester);
    await typeTitle(tester, 'The Lion King');
    await tester.tap(find.text('Suggest emoji'));
    await tester.pumpAndSettle();
    await typeTitle(tester, 'Sholay');
    expect(find.text('🦁🐗🐒'), findsNothing);
    expect(find.text('Suggest emoji'), findsOneWidget);
  });

  testWidgets('no clues: it says to write one', (tester) async {
    answer = (_) async => const [];
    await open(tester);
    await typeTitle(tester, 'My cousin’s short film');
    await tester.tap(find.text('Suggest emoji'));
    await tester.pumpAndSettle();
    expect(
      find.text('No emoji for that one. Spell it out yourself.'),
      findsOneWidget,
    );
    expect(clueField(tester), isEmpty);
  });

  testWidgets('a refusal shows the server’s words', (tester) async {
    answer = (_) async => throw const RateLimitedFailure(
          message: 'You have asked for a lot of clues today.',
        );
    await open(tester);
    await typeTitle(tester, 'Sholay');
    await tester.tap(find.text('Suggest emoji'));
    await tester.pumpAndSettle();
    expect(
      find.text('You have asked for a lot of clues today.'),
      findsOneWidget,
    );
  });

  testWidgets('without suggestions there is no button', (tester) async {
    await open(tester, withSuggestions: false);
    expect(find.text('Suggest emoji'), findsNothing);
  });
}
