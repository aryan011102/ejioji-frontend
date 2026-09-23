import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';
import 'enums.dart';
import 'person.dart';

/// What a row on the Notifications page is about.
enum ActivityKind {
  request('request'),
  match('match'),
  message('message'),
  takenDown('taken_down'),
  tilesReady('tiles_ready'),

  /// A kind this build has never heard of. Such a row is left off the page
  /// rather than drawn wrong.
  unknown('');

  const ActivityKind(this.wire);

  final String wire;

  static ActivityKind parse(String? raw) => values.firstWhere(
        (v) => v.wire == raw && v != unknown,
        orElse: () => unknown,
      );
}

/// One row on the Notifications page.
///
/// The server works every row out from what is true now, so nothing here can
/// be stale in the way a stored notification would be: a declined request or
/// an unmatched person is simply no longer in the list.
@immutable
class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.at,
    required this.isNew,
    this.person,
    this.requestId,
    this.matchId,
    this.messageKind,
    this.preview,
    this.reason,
    this.count,
  });

  final ActivityKind kind;
  final DateTime at;

  /// Since the page was last opened.
  final bool isNew;

  /// The other person, on a request, match or message.
  final Person? person;
  final String? requestId;
  final String? matchId;

  /// Set on a message: what kind it is, and the start of it for text.
  final MessageKind? messageKind;
  final String? preview;

  /// Why a moderator took something down. Null for a reason this build does
  /// not know, which still reads as taken down.
  final String? reason;

  /// How many new tiles.
  final int? count;

  static ActivityItem fromJson(Json j) {
    final person = j.objectOrNull('person');
    final message = j.objectOrNull('message');
    return ActivityItem(
      kind: ActivityKind.parse(j.strOrNull('kind')),
      at: j.time('at'),
      isNew: j.flag('new'),
      person: person == null ? null : Person.fromJson(person),
      requestId: j.strOrNull('request_id'),
      matchId: j.strOrNull('match_id'),
      messageKind: message == null
          ? null
          : MessageKind.parse(message.strOrNull('kind')),
      preview: message?.strOrNull('preview'),
      reason: j.strOrNull('reason'),
      count: j.intOrNull('count'),
    );
  }
}

/// The page, newest first, and how many rows are new: the bell's dot.
@immutable
class ActivityPage {
  const ActivityPage({required this.items, required this.newCount});

  final List<ActivityItem> items;
  final int newCount;

  static ActivityPage fromJson(Json j) => ActivityPage(
        items: [
          for (final item in j.objects('items').map(ActivityItem.fromJson))
            if (item.kind != ActivityKind.unknown) item,
        ],
        newCount: j.intOr('new', 0),
      );
}
