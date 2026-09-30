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
    this.productId = '',
    this.renews = false,
  });

  final String key;

  /// The App Store product that sells it.
  final String productId;

  /// Renews on its own in the App Store, or a one-off pass that just ends.
  final bool renews;

  /// `day` or `month`.
  final String unit;
  final int count;

  /// The list price. While [PremiumStatus.freeForNow] it is shown and not
  /// charged; after that the App Store's own price is shown when it loads,
  /// and this only stands in for it.
  final int pricePaise;

  String get title => count == 1 ? '1 $unit' : '$count ${unit}s';

  /// "month", "3 months": what comes after "every".
  String get period => count == 1 ? unit : title;

  /// Under the plan's name once plans are sold.
  String get storeSubtitle =>
      renews ? 'Renews every $period' : 'Once, for $title. Does not renew';

  /// What Apple asks to be said by the buy button: the price, the length, and
  /// whether and how it renews. [price] is the App Store's when it has loaded.
  String terms(String price) => renews
      ? '$price every $period. Renews automatically unless cancelled at '
          "least 24 hours before it ends, in your Apple ID's Subscriptions."
      : '$price once, for $title. Does not renew.';

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
        productId: j.strOrNull('product_id') ?? '',
        renews: j.flag('renews'),
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
    this.source,
  });

  final bool active;

  /// Starting a plan is still free, whatever its price says. Once false,
  /// plans are bought in the App Store.
  final bool freeForNow;
  final String? plan;
  final DateTime? endsAt;

  /// Where the running plan came from: `free`, `app_store` or `play_store`.
  final String? source;
  final List<PremiumPlan> plans;

  /// The running plan was bought in a store, so it is managed (and
  /// cancelled) there, not here.
  bool get fromStore => source == 'app_store' || source == 'play_store';

  /// The running plan, if any.
  PremiumPlan? get current =>
      plans.where((p) => p.key == plan).firstOrNull;

  static PremiumStatus fromJson(Json j) => PremiumStatus(
        active: j.flag('active'),
        freeForNow: j.flag('free_for_now'),
        plan: j.strOrNull('plan'),
        endsAt: j.timeOrNull('ends_at'),
        source: j.strOrNull('source'),
        plans: j
            .objects('plans')
            .map(PremiumPlan.fromJson)
            .toList(growable: false),
      );
}
