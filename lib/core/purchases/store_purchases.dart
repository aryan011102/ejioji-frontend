import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/env.dart';

/// Why a purchase did not go through, in words for the person.
class StoreFailure implements Exception {
  const StoreFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// How a purchase ended. A cancelled one is not a failure: nothing to say.
enum BuyOutcome { bought, cancelled }

/// The store this phone buys through, and how to talk about it.
enum Store {
  appStore(
    name: 'the App Store',
    title: 'App Store',
    source: 'app_store',
    account: 'Apple ID',
    device: 'iPhone',
  ),
  playStore(
    name: 'Google Play',
    title: 'Google Play',
    source: 'play_store',
    account: 'Google account',
    device: 'phone',
  );

  const Store({
    required this.name,
    required this.title,
    required this.source,
    required this.account,
    required this.device,
  });

  /// Mid-sentence: "Couldn't reach the App Store", "Couldn't reach Google Play".
  final String name;

  /// At the start of a sentence.
  final String title;

  /// What the server calls it in `PremiumStatus.source`.
  final String source;

  /// Whose purchases a restore looks for: "Apple ID", "Google account".
  final String account;
  final String device;

  /// Where a subscription bought in this store is managed and cancelled.
  /// Works from any device, so it also serves someone on the other platform.
  Uri manage({String? productId}) => switch (this) {
        Store.appStore =>
          Uri.parse('https://apps.apple.com/account/subscriptions'),
        Store.playStore => Uri.https(
            'play.google.com',
            '/store/account/subscriptions',
            {
              'package': 'com.theonebytwo.app',
              if (productId != null && productId.isNotEmpty) 'sku': productId,
            },
          ),
      };

  static Store? fromSource(String? source) =>
      Store.values.where((s) => s.source == source).firstOrNull;
}

/// Buying Premium in the App Store or Google Play, through RevenueCat.
///
/// This is the payment step and nothing else. Whether someone has Premium is
/// always the server's answer: after a purchase or a restore the app asks the
/// server to check the store (`POST /premium/sync`) and shows what it says.
/// Nothing here grants Premium, because a client that can grant itself
/// Premium is a client anyone can patch.
///
/// The person's RevenueCat id is our user id, so a purchase belongs to the
/// account, not to the phone. Every purchase and restore logs in first, so a
/// purchase can never land on an anonymous RevenueCat id.
///
/// iPhone with the Apple key, Android with the Google one. Everywhere else
/// (the browser, a build without the key) [available] is false and every call
/// does nothing.
class StorePurchases {
  StorePurchases();

  Future<void>? _configured;

  /// The store on this phone, whether or not this build can buy in it.
  Store? get store {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => Store.appStore,
      TargetPlatform.android => Store.playStore,
      _ => null,
    };
  }

  String get _key => switch (store) {
        Store.appStore => Env.revenueCatIosKey,
        Store.playStore => Env.revenueCatAndroidKey,
        null => '',
      };

  bool get available => _key.isNotEmpty;

  Future<void> _ensure() =>
      _configured ??= Purchases.configure(PurchasesConfiguration(_key));

  /// After sign-in. Best effort: a failure here is repeated before any
  /// purchase, where it matters.
  Future<void> logIn(String userId) async {
    if (!available) return;
    try {
      await _ensure();
      await Purchases.logIn(userId);
    } on PlatformException catch (e) {
      debugPrint('purchases: log in failed (${e.code})');
    }
  }

  /// On sign-out, so the next person on this phone does not inherit the
  /// last one's purchases. Best effort.
  Future<void> logOut() async {
    if (!available || _configured == null) return;
    try {
      await _ensure();
      await Purchases.logOut();
    } on PlatformException {
      // Already anonymous: nothing to forget.
    }
  }

  /// Google Play names a subscription by product and base plan
  /// ("theonebytwo_premium_m1:monthly"); the server and the App Store know
  /// only the product.
  static String productOf(String identifier) => identifier.split(':').first;

  /// The store's own price for each product, as the store formats it for
  /// this person ("₹799.00"). Empty for any it could not find; the page then
  /// shows the server's list price.
  Future<Map<String, String>> prices({
    required List<String> subscriptions,
    required List<String> oneOffs,
  }) async {
    if (!available) return const {};
    try {
      await _ensure();
      final found = [
        if (subscriptions.isNotEmpty) ...await Purchases.getProducts(subscriptions),
        if (oneOffs.isNotEmpty)
          ...await Purchases.getProducts(
            oneOffs,
            productCategory: ProductCategory.nonSubscription,
          ),
      ];
      return {for (final p in found) productOf(p.identifier): p.priceString};
    } on PlatformException {
      return const {};
    }
  }

  /// Buys [productId] as [userId]. Returns [BuyOutcome.cancelled] when the
  /// person backs out of the store's sheet; throws [StoreFailure] otherwise.
  ///
  /// [replacing] is the subscription this one takes over from, in this
  /// store. Apple moves a person between plans in one group on its own;
  /// Google needs to be told, or it sells a second subscription alongside
  /// the first.
  Future<BuyOutcome> buy({
    required String userId,
    required String productId,
    required bool renews,
    String? replacing,
  }) async {
    final store = this.store;
    if (!available || store == null) {
      throw const StoreFailure("onebytwo plus can't be bought here yet.");
    }
    try {
      await _ensure();
      await Purchases.logIn(userId);
      final products = await Purchases.getProducts(
        [productId],
        productCategory: renews
            ? ProductCategory.subscription
            : ProductCategory.nonSubscription,
      );
      if (products.isEmpty) {
        throw StoreFailure("This plan isn't available in ${store.name} yet.");
      }
      final change = renews &&
              store == Store.playStore &&
              replacing != null &&
              replacing.isNotEmpty &&
              replacing != productId
          ? StoreProductChangeInfo(
              replacing,
              replacementMode: StoreReplacementMode.withTimeProration,
            )
          : null;
      await Purchases.purchase(
        PurchaseParams.storeProduct(products.first, productChangeInfo: change),
      );
      return BuyOutcome.bought;
    } on PlatformException catch (e) {
      return switch (PurchasesErrorHelper.getErrorCode(e)) {
        PurchasesErrorCode.purchaseCancelledError => BuyOutcome.cancelled,
        PurchasesErrorCode.paymentPendingError => throw const StoreFailure(
            'Your payment is waiting for approval. onebytwo plus starts when it '
            'goes through.',
          ),
        PurchasesErrorCode.purchaseNotAllowedError => throw StoreFailure(
            'Purchases are turned off on this ${store.device}.',
          ),
        PurchasesErrorCode.networkError => throw StoreFailure(
            "Couldn't reach ${store.name}. Try again.",
          ),
        _ => throw StoreFailure(
            "${store.title} couldn't complete that. Nothing was charged.",
          ),
      };
    }
  }

  /// "Restore purchases": asks the store for everything this Apple ID or
  /// Google account bought and hands it to [userId]'s account.
  Future<void> restore({required String userId}) async {
    final store = this.store;
    if (!available || store == null) {
      throw const StoreFailure("Purchases can't be restored here yet.");
    }
    try {
      await _ensure();
      await Purchases.logIn(userId);
      await Purchases.restorePurchases();
    } on PlatformException {
      throw StoreFailure("Couldn't reach ${store.name}. Try again.");
    }
  }
}

final storePurchasesProvider = Provider<StorePurchases>((ref) => StorePurchases());
