import 'package:ejioji/features/insights/presentation/category_page.dart';
import 'package:ejioji/shared/models/enums.dart';
import 'package:ejioji/shared/models/tile.dart';
import 'package:flutter_test/flutter_test.dart';

Insight tile(TileCategory category, List<SourceProvider> providers) => Insight(
      key: '${category.wire}-${providers.map((p) => p.wire).join()}',
      origin: TileOrigin.template,
      category: category,
      value: const TileValue(kind: ValueKind.count, number: 1),
      displayValue: '1',
      caption: 'A caption.',
      support: 10,
      providers: providers,
      computedAt: DateTime.utc(2026, 9, 21),
    );

/// The order the whole picker walks, which a source's walk must not reorder.
const walk = [
  TileCategory.foodDelivery,
  TileCategory.goingOut,
  TileCategory.travel,
  TileCategory.music,
  TileCategory.fitness,
  TileCategory.netflix,
];

void main() {
  group("one app's categories", () {
    test('are every category its tiles land in, not just the first', () {
      // The bug this fixes: Gmail opened food delivery and stopped, so going
      // out, travel and moving were unreachable from its card even though
      // bookings had filled them.
      final candidates = [
        tile(TileCategory.foodDelivery, [SourceProvider.gmail]),
        tile(TileCategory.goingOut, [SourceProvider.gmail]),
        tile(TileCategory.travel, [SourceProvider.gmail]),
        tile(TileCategory.fitness, [SourceProvider.gmail]),
        tile(TileCategory.netflix, [SourceProvider.netflix]),
        tile(TileCategory.music, [SourceProvider.spotify]),
      ];

      expect(
        categoriesOf(SourceProvider.gmail, candidates, walk),
        [
          TileCategory.foodDelivery,
          TileCategory.goingOut,
          TileCategory.travel,
          TileCategory.fitness,
        ],
      );
    });

    test('leave out the categories other apps filled', () {
      final candidates = [
        tile(TileCategory.foodDelivery, [SourceProvider.gmail]),
        tile(TileCategory.netflix, [SourceProvider.netflix]),
        tile(TileCategory.music, [SourceProvider.spotify]),
      ];

      expect(
        categoriesOf(SourceProvider.netflix, candidates, walk),
        [TileCategory.netflix],
      );
    });

    test('keep the walk order, whatever order the tiles arrived in', () {
      final candidates = [
        tile(TileCategory.travel, [SourceProvider.gmail]),
        tile(TileCategory.foodDelivery, [SourceProvider.gmail]),
        tile(TileCategory.goingOut, [SourceProvider.gmail]),
      ];

      expect(
        categoriesOf(SourceProvider.gmail, candidates, walk),
        [TileCategory.foodDelivery, TileCategory.goingOut, TileCategory.travel],
      );
    });

    test('are empty for an app whose tiles nothing holds', () {
      final candidates = [tile(TileCategory.netflix, [SourceProvider.netflix])];

      expect(categoriesOf(SourceProvider.gmail, candidates, walk), isEmpty);
    });

    test('count a tile two apps fed for both of them', () {
      // A category can be fed by more than one source, and opening either
      // should reach it.
      final candidates = [
        tile(TileCategory.watching, [SourceProvider.youtube, SourceProvider.netflix]),
      ];

      expect(
        categoriesOf(SourceProvider.youtube, candidates, [TileCategory.watching]),
        [TileCategory.watching],
      );
      expect(
        categoriesOf(SourceProvider.netflix, candidates, [TileCategory.watching]),
        [TileCategory.watching],
      );
    });
  });
}
