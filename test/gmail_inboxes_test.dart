import 'package:ejioji/shared/format.dart';
import 'package:ejioji/shared/models/connection.dart';
import 'package:ejioji/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// The line under each Gmail inbox on the connect screen. The server counts;
/// these pin how the app words what it counted, since a wrong word here is the
/// only way to tell two inboxes apart wrongly.
void main() {
  final now = DateTime(2026, 9, 25);

  group('the line under an inbox', () {
    test('several kinds of receipt read as a span to today', () {
      final summary = ReceiptSummary(
        receipts: 312,
        firstAt: DateTime(2024, 1, 8),
        lastAt: DateTime(2026, 9, 20),
        groups: const ['food_delivery', 'shopping', 'travel'],
      );
      expect(summary.line(now: now), '312 receipts · Jan 2024 → today');
    });

    test('one kind of receipt reads as that kind only', () {
      final summary = ReceiptSummary(
        receipts: 88,
        firstAt: DateTime(2025, 2, 1),
        lastAt: DateTime(2026, 9, 1),
        groups: const ['travel'],
      );
      expect(summary.line(now: now), '88 receipts · travel only');
      expect(
        const ReceiptSummary(receipts: 3, groups: ['going_out']).line(now: now),
        '3 receipts · going out only',
      );
    });

    test('an inbox gone quiet ends at its last month, not today', () {
      final summary = ReceiptSummary(
        receipts: 1,
        firstAt: DateTime(2025, 3, 4),
        lastAt: DateTime(2025, 8, 30),
        groups: const ['food_delivery', 'shopping'],
      );
      expect(summary.line(now: now), '1 receipt · Mar 2025 → Aug 2025');
    });

    test('an empty inbox has no line of its own', () {
      expect(const ReceiptSummary(receipts: 0, groups: []).line(now: now), null);
    });

    test('a single old month is just that month', () {
      expect(
        monthSpan(DateTime(2025, 5, 2), DateTime(2025, 5, 28), now: now),
        'May 2025',
      );
    });
  });

  test('a connection carries its address and what it held', () {
    final c = Connection.fromJson({
      'id': 'a1',
      'provider': 'gmail',
      'status': 'active',
      'address': 'a.rao.work@gmail.com',
      'scopes': <String>[],
      'connected_at': '2026-09-25T10:00:00Z',
      'disconnected_at': null,
      'latest_run': null,
      'receipts': {
        'receipts': 88,
        'first_at': '2025-02-01T00:00:00Z',
        'last_at': '2026-09-01T00:00:00Z',
        'groups': ['travel'],
      },
    });
    expect(c.provider, SourceProvider.gmail);
    expect(c.address, 'a.rao.work@gmail.com');
    expect(c.receipts?.line(now: now), '88 receipts · travel only');
  });

  test('a server that sends neither still parses', () {
    final c = Connection.fromJson({
      'id': 'y1',
      'provider': 'youtube',
      'status': 'active',
      'scopes': <String>[],
      'connected_at': '2026-09-25T10:00:00Z',
    });
    expect((c.address, c.receipts), (null, null));
  });
}
