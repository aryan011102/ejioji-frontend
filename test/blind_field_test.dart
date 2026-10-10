import 'package:ejioji/features/blind/presentation/blind_field.dart';
import 'package:ejioji/features/blind/presentation/blind_layout.dart';
import 'package:ejioji/shared/models/blind.dart';
import 'package:ejioji/shared/widgets/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tap and hold-swipe on Go blind's plane (Aryan, 2026-10-04): a tap is passed
/// on (it no longer opens a profile, 2026-10-10); resting a finger on a tile
/// and sliding left asks; touching and moving at once moves the plane.
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

  late List<BlindTile> tapped;
  late List<BlindTile> asked;

  Future<void> pump(WidgetTester tester) async {
    tapped = [];
    asked = [];
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlindField(
            layout: BlindLayout(tiles),
            topInset: 60,
            onTap: tapped.add,
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

  /// Rests on [from] long enough to hold the tile, then slides left by
  /// [by], slowly.
  Future<void> holdAndSlide(WidgetTester tester, Offset from, double by) async {
    final gesture = await tester.startGesture(from);
    await tester.pump(BlindField.holdFor + const Duration(milliseconds: 40));
    const steps = 20;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(-by / steps, 0));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a tap is passed on, and never asks', (tester) async {
    await pump(tester);
    await tester.tapAt(onScreen(tester));
    await tester.pumpAndSettle();
    expect(tapped, hasLength(1));
    expect(asked, isEmpty);
  });

  testWidgets('rest, then slide left: asks about that tile', (tester) async {
    await pump(tester);
    await holdAndSlide(tester, onScreen(tester), 160);
    expect(asked, hasLength(1));
    expect(tapped, isEmpty);
  });

  testWidgets('rest, then a short slide: springs back, asks nothing', (
    tester,
  ) async {
    await pump(tester);
    await holdAndSlide(tester, onScreen(tester), 40);
    expect(asked, isEmpty);
    expect(tapped, isEmpty);
  });

  testWidgets('rest, then slide right: asks nothing', (tester) async {
    await pump(tester);
    await holdAndSlide(tester, onScreen(tester), -160);
    expect(asked, isEmpty);
  });

  testWidgets('touch and move at once moves the plane, never asks', (
    tester,
  ) async {
    await pump(tester);
    at = onScreen(tester);
    await tester.dragFrom(at, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(asked, isEmpty);
    expect(tapped, isEmpty);
    expect(onScreen(tester), isNot(at));
  });
}
