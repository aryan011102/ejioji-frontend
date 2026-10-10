import 'package:ejioji/shared/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('relativeTimeAgo', () {
    final now = DateTime(2026, 10, 10, 16, 42);

    test('a span takes "ago"', () {
      expect(
        relativeTimeAgo(now.subtract(const Duration(minutes: 4)), now: now),
        '4m ago',
      );
      expect(
        relativeTimeAgo(now.subtract(const Duration(hours: 2)), now: now),
        '2h ago',
      );
      expect(
        relativeTimeAgo(now.subtract(const Duration(days: 3)), now: now),
        '3d ago',
      );
    });

    test('"now" and "yesterday" do not', () {
      expect(
        relativeTimeAgo(now.subtract(const Duration(seconds: 20)), now: now),
        'now',
      );
      expect(
        relativeTimeAgo(DateTime(2026, 10, 9, 23), now: now),
        'yesterday',
      );
    });
  });
}
