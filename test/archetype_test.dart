import 'package:ejioji/data/profile_repository.dart';
import 'package:ejioji/data/providers.dart';
import 'package:ejioji/features/profile/presentation/archetype_page.dart';
import 'package:ejioji/shared/models/archetype.dart';
import 'package:ejioji/shared/models/person.dart';
import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// "Who your data thinks you are" (backend decision log, 2026-10-10): four
/// archetypes to choose one from, shown on the back of the photo tile.
void main() {
  Map<String, Object?> offerJson({String? chosen}) => {
        'options': [
          for (final (i, t) in [
            'The Quiet Romantic',
            'The Night Owl',
            'The Curious Mind',
            'The Weekend Wanderer',
          ].indexed)
            {'id': 'o$i', 'title': t, 'body': 'A line about $t.'},
        ],
        'chosen': chosen == null
            ? null
            : {'title': chosen, 'body': 'A line about $chosen.'},
        'personal': true,
        'ai': 'on',
        'refreshes_left': 2,
        'refreshes_per_day': 3,
      };

  group('what the server sends', () {
    test('an offer reads its four, the choice and the refreshes', () {
      final offer = ArchetypeOffer.fromJson(offerJson(chosen: 'The Night Owl'));
      expect(offer.options.map((o) => o.id), ['o0', 'o1', 'o2', 'o3']);
      expect(offer.chosen?.title, 'The Night Owl');
      expect(offer.personal, isTrue);
      expect(offer.ai, ArchetypeAi.on);
      expect(offer.refreshesLeft, 2);
    });

    test('an AI state this build does not know reads as off', () {
      expect(ArchetypeAi.parse('outdated'), ArchetypeAi.outdated);
      expect(ArchetypeAi.parse('something-new'), ArchetypeAi.off);
    });

    test('a card carries the archetype its person chose, or none', () {
      final base = {
        'user_id': 'u',
        'first_name': 'Priya',
        'age': 27,
        'city': 'delhi_ncr',
        'photos': <Object?>[],
        'tiles': <Object?>[],
      };
      expect(Candidate.fromJson(base).archetype, isNull);
      final card = Candidate.fromJson({
        ...base,
        'archetype': {'title': 'The Quiet Romantic', 'body': 'Nostalgic.'},
      });
      expect(card.archetype?.title, 'The Quiet Romantic');
    });
  });

  group('the photo tile', () {
    Future<void> pump(
      WidgetTester tester,
      Archetype? archetype, {
      bool theirs = false,
    }) =>
        tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.square(
                dimension: 180,
                child: PhotosTile(
                  photoUrls: const [],
                  archetype: archetype,
                  theirs: theirs,
                ),
              ),
            ),
          ),
        );

    testWidgets('a tap turns it over to the archetype, and back', (
      tester,
    ) async {
      await pump(
        tester,
        const Archetype(title: 'The Quiet Romantic', body: 'Nostalgic.'),
      );
      expect(find.text('WHO YOUR DATA THINKS YOU ARE'), findsNothing);

      await tester.tap(find.byType(PhotosTile));
      await tester.pumpAndSettle();
      expect(find.text('WHO YOUR DATA THINKS YOU ARE'), findsOneWidget);
      expect(find.text('The Quiet Romantic'), findsOneWidget);
      // The title only: the line under it is too long to read on a tile.
      expect(find.text('Nostalgic.'), findsNothing);

      await tester.tap(find.byType(PhotosTile));
      await tester.pumpAndSettle();
      expect(find.text('The Quiet Romantic'), findsNothing);
    });

    testWidgets('on somebody else\'s profile it speaks about them', (
      tester,
    ) async {
      await pump(
        tester,
        const Archetype(title: 'The Quiet Romantic', body: 'Nostalgic.'),
        theirs: true,
      );
      await tester.tap(find.byType(PhotosTile));
      await tester.pumpAndSettle();
      expect(find.text('WHO THEIR DATA THINKS THEY ARE'), findsOneWidget);
      expect(find.text('WHO YOUR DATA THINKS YOU ARE'), findsNothing);
    });

    testWidgets('with no archetype chosen, it stays photos', (tester) async {
      await pump(tester, null);
      await tester.tap(find.byType(PhotosTile));
      await tester.pumpAndSettle();
      expect(find.text('WHO YOUR DATA THINKS YOU ARE'), findsNothing);
    });
  });

  group('choosing one', () {
    testWidgets('nothing is saved until one is picked, then it is', (
      tester,
    ) async {
      final repo = _Repo(ArchetypeOffer.fromJson(offerJson()));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => TextButton(
              onPressed: () => context.push('/a'),
              child: const Text('open'),
            ),
          ),
          GoRoute(path: '/a', builder: (_, __) => const ArchetypePage()),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(393, 1000));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [profileRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Who your data thinks you are'), findsOneWidget);
      expect(find.text('The Night Owl'), findsOneWidget);
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();
      expect(repo.chosen, isNull);

      await tester.tap(find.text('The Night Owl'));
      await tester.pump();
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();
      expect(repo.chosen, 'o1');
      // Back where it was opened from.
      expect(find.text('open'), findsOneWidget);
    });
  });
}

class _Repo implements ProfileRepository {
  _Repo(this.offer);

  final ArchetypeOffer offer;
  String? chosen;

  @override
  Future<ArchetypeOffer> archetypes() async => offer;

  @override
  Future<Archetype> chooseArchetype(String optionId) async {
    chosen = optionId;
    final o = offer.options.firstWhere((o) => o.id == optionId);
    return Archetype(title: o.title, body: o.body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
