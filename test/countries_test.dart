import 'package:ejioji/data/auth_repository.dart';
import 'package:ejioji/data/verification_repository.dart';
import 'package:ejioji/shared/models/enums.dart';
import 'package:ejioji/shared/models/profile.dart';
import 'package:ejioji/shared/models/tile.dart';
import 'package:ejioji/shared/widgets/city_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shapes copied from the backend's profile/schemas.py (`countries`),
/// verification_router.py (`eligible`) and accounts/router.py (`abroad`).
void main() {
  Map<String, Object?> option(String key, String label) =>
      {'key': key, 'label': label};

  final grouped = ProfileOptions.fromJson({
    'genders': <Object>[],
    'cities': [
      {...option('pune', 'Pune'), 'country': 'in'},
      {...option('london', 'London'), 'country': 'gb'},
      {...option('leicester', 'Leicester'), 'country': 'gb'},
    ],
    'countries': [
      {
        'key': 'in',
        'label': 'India',
        'cities': [option('pune', 'Pune')],
      },
      {
        'key': 'gb',
        'label': 'United Kingdom',
        'cities': [option('london', 'London'), option('leicester', 'Leicester')],
      },
    ],
    'languages': <Object>[],
    'educations': <Object>[],
    'pronouns': <Object>[],
  });

  test('the options carry the cities grouped by country', () {
    expect(grouped.countries.map((c) => c.key), ['in', 'gb']);
    expect(grouped.countries[1].cities.map((c) => c.key), ['london', 'leicester']);
    final older = ProfileOptions.fromJson({'cities': <Object>[]});
    expect(older.countries, isEmpty);
  });

  test('every city abroad parses, and an unknown one does not', () {
    for (final key in ['new_york', 'bay_area', 'london', 'toronto', 'dubai', 'abu_dhabi', 'sydney', 'singapore']) {
      expect(City.parse(key), isNot(City.unknown), reason: key);
    }
    expect(City.parse('paris'), City.unknown);
  });

  Future<City?> pick(
    WidgetTester tester,
    ProfileOptions options, {
    String search = '',
    required String tap,
  }) async {
    City? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await pickCity(context, options),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (search.isNotEmpty) {
      await tester.enterText(find.byType(TextField), search);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(tap).last);
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('every city is listed under its country', (tester) async {
    expect(await pick(tester, grouped, tap: 'Leicester'), City.leicester);
  });

  testWidgets('searching a country keeps all of its cities', (tester) async {
    await pick(tester, grouped, search: 'uk', tap: 'London');
    // Picked and closed; reopen to look at the narrowed list itself.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'uk');
    await tester.pumpAndSettle();
    expect(find.text('London'), findsOneWidget);
    expect(find.text('Leicester'), findsOneWidget);
    expect(find.text('Pune'), findsNothing);
  });

  testWidgets('a city is found by the name people still use', (tester) async {
    final india = ProfileOptions.fromJson({
      'cities': [
        {...option('bengaluru', 'Bengaluru'), 'country': 'in'},
      ],
      'countries': [
        {
          'key': 'in',
          'label': 'India',
          'cities': [option('bengaluru', 'Bengaluru')],
        },
      ],
    });
    expect(await pick(tester, india, search: 'Bangalore', tap: 'Bengaluru'), City.bengaluru);
  });

  testWidgets('an older server, with no countries, is one list of cities', (tester) async {
    final flat = ProfileOptions(
      genders: const [],
      cities: [PromptOption.fromJson(option('pune', 'Pune'))],
      languages: const [],
      educations: const [],
      pronouns: const [],
    );
    expect(await pick(tester, flat, tap: 'Pune'), City.pune);
  });

  test('DigiLocker is offered only where the server says the profile is in India', () {
    Map<String, Object?> body({bool? eligible}) => {
          'status': 'none',
          'verified': false,
          'available': true,
          if (eligible != null) 'eligible': eligible,
        };
    expect(Verification.fromJson(body(eligible: false)).inIndia, isFalse);
    expect(Verification.fromJson(body(eligible: true)).inIndia, isTrue);
    // An older server says nothing, and only India was open then.
    expect(Verification.fromJson(body()).inIndia, isTrue);
  });

  test('a number from abroad signs in the way the server names for abroad', () {
    expect(signInMethodFrom({'phone': 'otp', 'abroad': 'firebase'}, abroad: false), 'otp');
    expect(signInMethodFrom({'phone': 'otp', 'abroad': 'firebase'}, abroad: true), 'firebase');
    expect(signInMethodFrom({'phone': 'otp', 'abroad': null}, abroad: true), isNull);
    expect(signInMethodFrom({'phone': 'firebase', 'abroad': null}, abroad: true), 'firebase');
    // An older server has no `abroad`: closed, rather than codes that never arrive.
    expect(signInMethodFrom({'phone': 'otp'}, abroad: true), isNull);
  });
}
