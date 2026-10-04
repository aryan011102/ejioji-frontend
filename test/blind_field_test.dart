import 'package:ejioji/features/blind/presentation/blind_field.dart';
import 'package:ejioji/features/blind/presentation/blind_layout.dart';
import 'package:ejioji/shared/models/blind.dart';
import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tap and swipe on Go blind's plane (Aryan, 2026-10-04): a tap lifts a tile,
/// a lifted tile slides right to ask, a tap on it opens the profile.
void main() {
  Map<String, Object?> insight(String key, String value) => {
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

  final tiles = BlindDeal.fromJson({
    'seed': 1,
    'people': [
      {
        'user_id': 'a',
        'first_name': 'Priya',
        'age': 27,
        'city': 'delhi_ncr',
        'tiles': [for (var i = 0; i < 30; i++) insight('k$i', '$i')],
      },
    ],
    'deal': [
      for (var i = 0; i < 30; i++)
        {'user_id': 'a', 'kind': 'insight', 'key': 'k$i'},
    ],
  }).tiles;

  late List<BlindTile> opened;
  late List<BlindTile> asked;

  Future<void> pump(WidgetTester tester) async {
    opened = [];
    asked = [];
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlindField(
            layout: BlindLayout(tiles),
            topInset: 60,
            bottomInset: 120,
            onOpen: opened.add,
            onChat: (t) async => asked.add(t),
            onRunningLow: () {},
          ),
        ),
      ),
    );
  }

  /// A tile wholly on screen, nearest the top left. Widget order is no guide:
  /// the plane builds blocks that only hang onto the screen's edge.
  late Offset at;
  Offset onScreen(WidgetTester tester) {
    final view = Offset.zero & const Size(393, 852);
    final rects = [
      for (final e in find.byType(InsightTile).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ].where((r) => view.contains(r.topLeft) && view.contains(r.bottomRight))
        .toList()
      ..sort(
        (a, b) => (a.top - b.top).abs() > 1
            ? a.top.compareTo(b.top)
            : a.left.compareTo(b.left),
      );
    return rects.first.center;
  }

  const hint = 'Swipe right to chat · tap to open';

  testWidgets('a tap lifts a tile, and a second tap opens whose it is', (
    tester,
  ) async {
    await pump(tester);
    final tile = onScreen(tester);
    expect(find.text(hint), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.text(hint), matching: find.byType(AnimatedOpacity)),
      ).opacity,
      0,
    );

    await tester.tapAt(tile);
    await tester.pumpAndSettle();
    expect(opened, isEmpty, reason: 'the first tap only lifts');
    expect(
      tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.text(hint), matching: find.byType(AnimatedOpacity)),
      ).opacity,
      1,
    );

    await tester.tapAt(tile);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
  });

  testWidgets('a lifted tile swiped right, slowly, asks about it', (
    tester,
  ) async {
    await pump(tester);
    at = onScreen(tester);
    await tester.tapAt(at);
    await tester.pumpAndSettle();

    // Slow on purpose: the old flick needed speed, and that was the problem.
    final gesture = await tester.startGesture(at);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(asked, hasLength(1));
    expect(opened, isEmpty);
  });

  testWidgets('a short slide springs back without asking', (tester) async {
    await pump(tester);
    at = onScreen(tester);
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(at);
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(6, 0));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(asked, isEmpty);
  });

  testWidgets('a swipe on a tile not lifted moves the plane, never asks', (
    tester,
  ) async {
    await pump(tester);
    at = onScreen(tester);
    await tester.dragFrom(at, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(asked, isEmpty);
    expect(onScreen(tester), isNot(at));
  });
}
