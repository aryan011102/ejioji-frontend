import 'package:ejioji/core/purchases/store_purchases.dart';
import 'package:ejioji/shared/models/premium.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('store purchases', () {
    test('a Google Play subscription id maps back to its product', () {
      expect(
        StorePurchases.productOf('theonebytwo_premium_m1:monthly'),
        'theonebytwo_premium_m1',
      );
      expect(
        StorePurchases.productOf('theonebytwo_premium_d3'),
        'theonebytwo_premium_d3',
      );
    });

    test('the server source names the store a plan is managed in', () {
      expect(Store.fromSource('app_store'), Store.appStore);
      expect(Store.fromSource('play_store'), Store.playStore);
      expect(Store.fromSource('free'), isNull);
      expect(Store.fromSource(null), isNull);
    });

    test('Google Play subscriptions are managed on Play, for this app', () {
      final url = Store.playStore.manage(productId: 'theonebytwo_premium_m3');
      expect(url.host, 'play.google.com');
      expect(url.queryParameters['package'], 'com.theonebytwo.app');
      expect(url.queryParameters['sku'], 'theonebytwo_premium_m3');
      expect(
        Store.appStore.manage().toString(),
        'https://apps.apple.com/account/subscriptions',
      );
    });

    test('renewal terms name the account the plan is cancelled in', () {
      const month = PremiumPlan(
        key: 'm1',
        unit: 'month',
        count: 1,
        pricePaise: 79900,
        productId: 'theonebytwo_premium_m1',
        renews: true,
      );
      expect(month.terms('₹799.00'), contains("Apple ID's Subscriptions"));
      expect(
        month.terms('₹799.00', account: Store.playStore.account),
        contains("Google account's Subscriptions"),
      );
    });
  });
}
