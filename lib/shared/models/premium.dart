import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';

/// One plan the server offers: how long it runs and what it costs. Nothing on
/// this side decides either.
@immutable
class PremiumPlan {
  const PremiumPlan({
    required this.key,
    required this.unit,
    required this.count,
    required this.pricePaise,
  });

  final String key;

  /// `day` or `month`.
  final String unit;
  final int count;

  /// The list price. While [PremiumStatus.freeForNow] it is shown and not
  /// charged.
  final int pricePaise;

  String get title => count == 1 ? '1 $unit' : '$count ${unit}s';

  /// "₹1,799": rupees, grouped the Indian way.
  String get price => '₹${_indian(pricePaise ~/ 100)}';

  static String _indian(int n) {
    final s = '$n';
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  static PremiumPlan fromJson(Json j) => PremiumPlan(
        key: j.str('key'),
        unit: j.str('unit'),
        count: j.integer('count'),
        pricePaise: j.intOr('price_paise', 0),
      );
}

/// Whether this person has Premium now, and until when. Decided by the
/// server on every read; the app never holds Premium in local state, because
/// a client that can grant itself Premium is a client anyone can patch.
@immutable
class PremiumStatus {
  const PremiumStatus({
    required this.active,
    required this.plans,
    this.freeForNow = false,
    this.plan,
    this.endsAt,
  });

  final bool active;

  /// No payment provider yet: every plan starts free whatever its price.
  final bool freeForNow;
  final String? plan;
  final DateTime? endsAt;
  final List<PremiumPlan> plans;

  static PremiumStatus fromJson(Json j) => PremiumStatus(
        active: j.flag('active'),
        freeForNow: j.flag('free_for_now'),
        plan: j.strOrNull('plan'),
        endsAt: j.timeOrNull('ends_at'),
        plans: j
            .objects('plans')
            .map(PremiumPlan.fromJson)
            .toList(growable: false),
      );
}
