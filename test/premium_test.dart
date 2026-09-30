import 'package:ejioji/features/account/presentation/subscription_page.dart';
import 'package:ejioji/shared/models/person.dart';
import 'package:ejioji/shared/models/premium.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('premium in the App Store', () {
    PremiumStatus sold({String? plan, String? source}) =>
        PremiumStatus.fromJson({
          'active': plan != null,
          'plan': plan,
          'ends_at': plan == null ? null : '2026-11-30T08:00:00Z',
          'source': source,
          'free_for_now': false,
          'plans': [
            {
              'key': 'd3',
              'unit': 'day',
              'count': 3,
              'price_paise': 19900,
              'product_id': 'theonebytwo_premium_d3',
              'renews': false,
            },
            {
              'key': 'm1',
              'unit': 'month',
              'count': 1,
              'price_paise': 79900,
              'product_id': 'theonebytwo_premium_m1',
              'renews': true,
            },
            {
              'key': 'm12',
              'unit': 'month',
              'count': 12,
              'price_paise': 499900,
              'product_id': 'theonebytwo_premium_m12',
              'renews': true,
            },
          ],
        });

    test('each plan names its product and whether it renews', () {
      final status = sold();
      expect(
        [for (final p in status.plans) (p.productId, p.renews)],
        [
          ('theonebytwo_premium_d3', false),
          ('theonebytwo_premium_m1', true),
          ('theonebytwo_premium_m12', true),
        ],
      );
    });

    test('the terms say the price, the length and how it renews', () {
      final [pass, month, year] = sold().plans;
      expect(pass.terms('₹199.00'), '₹199.00 once, for 3 days. Does not renew.');
      expect(month.terms('₹799.00'), startsWith('₹799.00 every month. Renews'));
      expect(year.terms('₹4,999.00'), startsWith('₹4,999.00 every 12 months.'));
      expect(month.terms('x'), contains('24 hours'));
      expect(pass.storeSubtitle, 'Once, for 3 days. Does not renew');
      expect(month.storeSubtitle, 'Renews every month');
    });

    test('a store plan knows it came from the store', () {
      final status = sold(plan: 'm1', source: 'app_store');
      expect(status.fromStore, isTrue);
      expect(status.current?.renews, isTrue);
      expect(sold(plan: 'm1', source: 'free').fromStore, isFalse);
    });

    test('the subscription page says who to cancel with, and when not to', () {
      expect(
        SubscriptionPage.footer(sold(plan: 'm1', source: 'app_store')),
        startsWith('Bought in the App Store. It renews on its own'),
      );
      expect(
        SubscriptionPage.footer(sold(plan: 'd3', source: 'app_store')),
        startsWith('Bought in the App Store, once. It does not renew.'),
      );
      expect(
        SubscriptionPage.footer(sold(plan: 'm1', source: 'free')),
        startsWith('This plan was free.'),
      );
    });
  });

  group('premium', () {
    test('plans come from the server with their length and price', () {
      final status = PremiumStatus.fromJson({
        'active': false,
        'plan': null,
        'ends_at': null,
        'free_for_now': true,
        'plans': [
          {'key': 'd3', 'unit': 'day', 'count': 3, 'price_paise': 19900},
          {'key': 'm1', 'unit': 'month', 'count': 1, 'price_paise': 79900},
          {'key': 'm3', 'unit': 'month', 'count': 3, 'price_paise': 149900},
          {'key': 'm12', 'unit': 'month', 'count': 12, 'price_paise': 499900},
        ],
      });
      expect(status.active, isFalse);
      expect(status.freeForNow, isTrue);
      expect(status.endsAt, isNull);
      expect(
        [for (final p in status.plans) p.title],
        ['3 days', '1 month', '3 months', '12 months'],
      );
      expect(
        [for (final p in status.plans) p.price],
        ['₹199', '₹799', '₹1,499', '₹4,999'],
      );
    });

    test('a running plan says which and until when', () {
      final status = PremiumStatus.fromJson({
        'active': true,
        'plan': 'm3',
        'ends_at': '2026-12-27T08:00:00Z',
        'plans': const [],
      });
      expect(status.active, isTrue);
      expect(status.plan, 'm3');
      expect(status.endsAt!.toUtc(), DateTime.utc(2026, 12, 27, 8));
    });

    test('a price past a lakh groups the Indian way', () {
      const plan = PremiumPlan(
        key: 'x',
        unit: 'month',
        count: 12,
        pricePaise: 12345600,
      );
      expect(plan.price, '₹1,23,456');
    });

    test('a locked views list keeps its count and has nobody in it', () {
      final views = ProfileViews.fromJson({
        'total': 4,
        'visitors': const [],
        'locked': true,
      });
      expect(views.locked, isTrue);
      expect(views.total, 4);
      expect(views.visitors, isEmpty);
    });

    test('an older server that sends no lock reads as unlocked', () {
      final views = ProfileViews.fromJson({'total': 0, 'visitors': const []});
      expect(views.locked, isFalse);
    });
  });

  group('saved profiles', () {
    test('a saved list knows who is on it', () {
      final saved = SavedProfiles.fromJson({
        'locked': false,
        'saved': [
          {
            'saved_at': '2026-09-27T08:00:00Z',
            'person': {
              'user_id': '11111111-1111-1111-1111-111111111111',
              'first_name': 'Ananya',
              'age': 28,
              'city': 'bengaluru',
            },
          },
        ],
      });
      expect(saved.locked, isFalse);
      expect(saved.has('11111111-1111-1111-1111-111111111111'), isTrue);
      expect(saved.has('22222222-2222-2222-2222-222222222222'), isFalse);
    });

    test('without Premium the list is locked and empty', () {
      final saved = SavedProfiles.fromJson({'locked': true, 'saved': const []});
      expect(saved.locked, isTrue);
      expect(saved.saved, isEmpty);
    });
  });
}
