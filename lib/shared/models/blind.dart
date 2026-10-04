import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';
import 'person.dart';
import 'tile.dart';

/// One tile in Go blind, and whose it is.
///
/// The person travels with the tile because a tap opens their profile at once:
/// fetching it then would show a different profile from the one whose line
/// was tapped. Nothing on the tile itself names them.
@immutable
class BlindTile {
  const BlindTile({required this.person, required this.tile});

  final Candidate person;
  final ProfileTile tile;

  /// Unique within a deal: one person never shows one tile twice.
  String get id => '${person.userId}/${tile.kind.wire}/${tile.key}';
}

/// A page of a deal. [tiles] are in the order the server dealt them.
@immutable
class BlindPage {
  const BlindPage({required this.seed, required this.tiles, this.nextCursor});

  /// Sent back for more of this same deal.
  final int seed;
  final List<BlindTile> tiles;
  final int? nextCursor;

  bool get hasMore => nextCursor != null;

  /// A dealt tile that is not on its person's card is dropped rather than
  /// guessed at: the card is what a tap opens, and the two must agree.
  static BlindPage fromJson(Json j) {
    final people = {
      for (final p in Candidate.listFrom(j.objects('people'))) p.userId: p,
    };
    final tiles = <BlindTile>[];
    for (final d in j.objects('deal')) {
      final person = people[d.str('user_id')];
      if (person == null) continue;
      final kind = d.str('kind');
      final key = d.str('key');
      for (final t in person.tiles) {
        if (t.kind.wire == kind && t.key == key) {
          tiles.add(BlindTile(person: person, tile: t));
          break;
        }
      }
    }
    return BlindPage(
      seed: j.intOrNull('seed') ?? 0,
      tiles: tiles,
      nextCursor: j.intOrNull('next_cursor'),
    );
  }
}
