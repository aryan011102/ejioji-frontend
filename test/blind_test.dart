import 'package:ejioji/core/network/json.dart';
import 'package:ejioji/features/blind/presentation/blind_layout.dart';
import 'package:ejioji/shared/models/blind.dart';
import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Go blind: the deal as the server sends it, and the plane it is laid on.
void main() {
  Json insight(String key, String value, {String category = 'music'}) => {
        'kind': 'insight',
        'key': key,
        'category': category,
        'insight': {
          'key': key,
          'origin': 'template',
          'category': category,
          'value': {'kind': 'count', 'number': 1},
          'display_value': value,
          'caption': 'c',
          'support': 10,
          'providers': <Object?>[],
          'computed_at': '2026-10-04T04:30:00Z',
        },
      };

  Json answer(String key) => {
        'kind': 'prompt',
        'key': key,
        'category': 'food_delivery',
        'prompt': {
          'prompt_key': key,
          'category': 'food_delivery',
          'question': 'The thing ordered at 1am',
          'kind': 'text',
          'answer': 'Maggi, twice',
          'answered_at': '2026-10-04T04:30:00Z',
        },
      };

  Json card(String id, List<Json> tiles) => {
        'user_id': id,
        'first_name': 'Priya',
        'age': 27,
        'city': 'delhi_ncr',
        'tiles': tiles,
      };

  group('a page of the deal', () {
    test('keeps the server order and pairs each tile with its person', () {
      final page = BlindPage.fromJson({
        'seed': 42,
        'next_cursor': 12,
        'people': [
          card('a', [insight('a1', '142'), answer('a2')]),
          card('b', [insight('b1', '62%')]),
        ],
        'deal': [
          {'user_id': 'b', 'kind': 'insight', 'key': 'b1'},
          {'user_id': 'a', 'kind': 'prompt', 'key': 'a2'},
          {'user_id': 'a', 'kind': 'insight', 'key': 'a1'},
        ],
      });
      expect(page.seed, 42);
      expect(page.hasMore, isTrue);
      expect([for (final t in page.tiles) t.id], ['b/insight/b1', 'a/prompt/a2', 'a/insight/a1']);
      expect(page.tiles.first.person.userId, 'b');
    });

    test('drops a dealt tile its card does not hold, rather than guessing', () {
      // The card is what a tap opens; a tile that is not on it would open a
      // profile without the line that was tapped.
      final page = BlindPage.fromJson({
        'seed': 1,
        'people': [
          card('a', [insight('a1', '142')]),
        ],
        'deal': [
          {'user_id': 'a', 'kind': 'insight', 'key': 'gone'},
          {'user_id': 'nobody', 'kind': 'insight', 'key': 'a1'},
          {'user_id': 'a', 'kind': 'insight', 'key': 'a1'},
        ],
      });
      expect([for (final t in page.tiles) t.id], ['a/insight/a1']);
      expect(page.hasMore, isFalse);
    });
  });

  group('the plane', () {
    List<BlindTile> deal(int n) => BlindPage.fromJson({
          'seed': 1,
          'people': [
            card('p', [
              for (var i = 0; i < n; i++)
                i.isEven ? insight('k$i', '$i') : answer('k$i'),
            ]),
          ],
          'deal': [
            for (var i = 0; i < n; i++)
              {'user_id': 'p', 'kind': i.isEven ? 'insight' : 'prompt', 'key': 'k$i'},
          ],
        }).tiles;

    test('a lattice of eighteen with no big square', () {
      expect(BlindLayout.slots, hasLength(18));
      expect(
        BlindLayout.slots.map((s) => s.$3),
        isNot(contains(TileSize.large)),
      );
      // Every cell of the four by six block is covered exactly once.
      final covered = <(int, int)>{};
      for (final (col, row, size) in BlindLayout.slots) {
        for (var c = 0; c < size.crossAxisCells; c++) {
          for (var r = 0; r < size.mainAxisCells; r++) {
            expect(covered.add((col + c, row + r)), isTrue);
          }
        }
      }
      expect(covered, hasLength(BlindLayout.cols * BlindLayout.rows));
    });

    test('a block is the same every time it is looked at', () {
      final layout = BlindLayout(deal(60));
      final first = layout.block(3, -2);
      layout.block(0, 0);
      layout.block(-5, 7);
      expect(layout.block(3, -2), same(first));
    });

    test('new blocks take tiles not yet laid down before repeating any', () {
      final layout = BlindLayout(deal(54));
      final seen = <String>{
        for (final b in [(0, 0), (1, 0), (0, 1)])
          for (final t in layout.block(b.$1, b.$2)) t.id,
      };
      expect(seen, hasLength(54));
    });

    test('an answer never lands in a small square when a slot fits', () {
      final layout = BlindLayout(deal(60));
      final tiles = layout.block(0, 0);
      for (var k = 0; k < tiles.length; k++) {
        if (BlindLayout.slots[k].$3 == TileSize.small) {
          expect(tiles[k].tile.isAnswer, isFalse, reason: 'slot $k');
        }
      }
    });

    test('runs low with fewer than two blocks unseen, and wraps after', () {
      final layout = BlindLayout(deal(40));
      expect(layout.runningLow, isFalse);
      layout.block(0, 0);
      expect(layout.runningLow, isTrue);
      // Past the end it repeats rather than running dry.
      expect(layout.block(9, 9), hasLength(18));
    });

    test('nothing dealt is an empty plane, not a crash', () {
      expect(BlindLayout(const []).block(0, 0), isEmpty);
    });
  });
}
