import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';

/// "Who your data thinks you are" (Aryan's call, 2026-10-10): a title like
/// "The Quiet Romantic" and one line under it, on the back of the photo tile.
@immutable
class Archetype {
  const Archetype({required this.title, required this.body});

  final String title;
  final String body;

  static Archetype? maybe(Json? j) => j == null
      ? null
      : Archetype(title: j.str('title'), body: j.str('body'));
}

/// One of the four on offer, which choosing sends back by [id].
@immutable
class ArchetypeOption {
  const ArchetypeOption({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  static ArchetypeOption fromJson(Json j) => ArchetypeOption(
        id: j.str('id'),
        title: j.str('title'),
        body: j.str('body'),
      );
}

/// Whether the AI may write someone's archetypes, as the server says.
enum ArchetypeAi {
  /// Allowed, under a notice that covers archetypes.
  on,

  /// Allowed under an older notice that did not mention archetypes: agreeing
  /// again would let it.
  outdated,

  /// Not allowed. The four come from a library, chosen by code.
  off;

  static ArchetypeAi parse(String? raw) => switch (raw) {
        'on' => on,
        'outdated' => outdated,
        _ => off,
      };
}

/// What the archetype page shows: the four to choose from, and the one chosen.
@immutable
class ArchetypeOffer {
  const ArchetypeOffer({
    required this.options,
    required this.personal,
    required this.ai,
    required this.refreshesLeft,
    required this.refreshesPerDay,
    this.chosen,
  });

  final List<ArchetypeOption> options;
  final Archetype? chosen;

  /// Written from their own data, rather than the library's.
  final bool personal;
  final ArchetypeAi ai;
  final int refreshesLeft;
  final int refreshesPerDay;

  static ArchetypeOffer fromJson(Json j) => ArchetypeOffer(
        options: [for (final o in j.objects('options')) ArchetypeOption.fromJson(o)],
        chosen: Archetype.maybe(j.objectOrNull('chosen')),
        personal: j.flag('personal'),
        ai: ArchetypeAi.parse(j.strOrNull('ai')),
        refreshesLeft: j.intOr('refreshes_left', 0),
        refreshesPerDay: j.intOr('refreshes_per_day', 0),
      );
}
