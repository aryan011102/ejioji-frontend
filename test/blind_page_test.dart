import 'dart:async';

import 'package:ejioji/data/blind_controller.dart';
import 'package:ejioji/data/providers.dart';
import 'package:ejioji/features/blind/presentation/blind_page.dart';
import 'package:ejioji/shared/models/blind.dart' as m;
import 'package:ejioji/shared/models/profile.dart';
import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A controller that deals from a list instead of the network, and counts
/// how often it was asked to.
class _Dealer extends BlindController {
  _Dealer(this.pages);

  /// Handed out in turn, one per deal.
  final List<List<m.BlindTile>> pages;
  int deals = 0;

  @override
  BlindState build() => const BlindState();

  @override
  Future<void> shuffle() async {
    final tiles = pages[deals.clamp(0, pages.length - 1)];
    deals++;
    state = state.copyWith(started: true, tiles: tiles, deal: deals);
  }
}

Map<String, Object?> _insight(String key, String value) => {
      'kind': 'insight',
      'key': key,
      'category': 'watching',
      'insight': {
        'key': key,
        'origin': 'template',
        'category': 'watching',
        'value': {'kind': 'count', 'number': 1},
        'display_value': value,
        'caption': 'c',
        'support': 10,
        'providers': <Object?>[],
        'computed_at': '2026-10-04T04:30:00Z',
      },
    };

List<m.BlindTile> _deal(int n) => m.BlindDeal.fromJson({
      'seed': 1,
      'people': [
        {
          'user_id': 'a',
          'first_name': 'Priya',
          'age': 27,
          'city': 'delhi_ncr',
          'tiles': [for (var i = 0; i < n; i++) _insight('k$i', '${i * 7}')],
        },
      ],
      'deal': [
        for (var i = 0; i < n; i++)
          {'user_id': 'a', 'kind': 'insight', 'key': 'k$i'},
      ],
    }).tiles;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'blind.drag_hint_seen': true});
  });

  Future<_Dealer> pump(
    WidgetTester tester,
    List<List<m.BlindTile>> pages,
  ) async {
    final dealer = _Dealer(pages);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blindProvider.overrideWith(() => dealer),
          // The page holds your own profile for its sheet; none of these
          // tests open the sheet, so it never needs to arrive.
          myProfileProvider.overrideWith((_) => Completer<MyProfile>().future),
        ],
        child: const MaterialApp(home: Scaffold(body: BlindPage())),
      ),
    );
    return dealer;
  }

  testWidgets('a deal is drawn as tiles on the plane', (tester) async {
    final dealer = await pump(tester, [_deal(9)]);
    dealer.enter();
    await tester.pump();
    expect(find.byType(InsightTile), findsWidgets);
  });

  testWidgets('an empty deal says so, and turning back deals again', (
    tester,
  ) async {
    // The bug of 2026-10-04: the first deal came back empty, people arrived
    // after a filter change, and Blind kept showing nobody because it only
    // ever dealt once.
    final dealer = await pump(tester, [const [], _deal(9)]);
    dealer.enter();
    await tester.pump();
    expect(find.text('Nobody to go blind on yet'), findsOneWidget);

    dealer.enter();
    await tester.pump();
    expect(dealer.deals, 2);
    expect(find.byType(InsightTile), findsWidgets);
  });

  testWidgets('a deal with tiles is kept on turning back', (tester) async {
    final dealer = await pump(tester, [_deal(9), _deal(3)]);
    dealer.enter();
    await tester.pump();
    dealer.enter();
    expect(dealer.deals, 1);
  });
}
