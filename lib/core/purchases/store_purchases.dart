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

/// Buying Premium in the App Store, through RevenueCat.
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
/// iPhone only, and only in a build given a key. Everywhere else (Android
/// until Play is set up, the browser, a build without the key) [available] is
/// false and every call does nothing.
class StorePurchases {
  StorePurchases();

  Future<void>? _configured;

  bool get available =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      Env.revenueCatIosKey.isNotEmpty;

  Future<void> _ensure() => _configured ??=
      Purchases.configure(PurchasesConfiguration(Env.revenueCatIosKey));

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

  /// The App Store's own price for each product, as Apple formats it for
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
      return {for (final p in found) p.identifier: p.priceString};
    } on PlatformException {
      return const {};
    }
  }

  /// Buys [productId] as [userId]. Returns [BuyOutcome.cancelled] when the
  /// person backs out of Apple's sheet; throws [StoreFailure] otherwise.
  Future<BuyOutcome> buy({
    required String userId,
    required String productId,
    required bool renews,
  }) async {
    if (!available) {
      throw const StoreFailure('onebytwo plus can be bought in the iPhone app.');
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
        throw const StoreFailure(
          "This plan isn't available in the App Store yet.",
        );
      }
      await Purchases.purchase(PurchaseParams.storeProduct(products.first));
      return BuyOutcome.bought;
    } on PlatformException catch (e) {
      return switch (PurchasesErrorHelper.getErrorCode(e)) {
        PurchasesErrorCode.purchaseCancelledError => BuyOutcome.cancelled,
        PurchasesErrorCode.paymentPendingError => throw const StoreFailure(
            'Your payment is waiting for approval. onebytwo plus starts when it '
            'goes through.',
          ),
        PurchasesErrorCode.purchaseNotAllowedError => throw const StoreFailure(
            'Purchases are turned off on this iPhone.',
          ),
        PurchasesErrorCode.networkError => throw const StoreFailure(
            "Couldn't reach the App Store. Try again.",
          ),
        _ => throw const StoreFailure(
            "The App Store couldn't complete that. Nothing was charged.",
          ),
      };
    }
  }

  /// "Restore purchases": asks Apple for everything this Apple ID bought and
  /// hands it to [userId]'s account.
  Future<void> restore({required String userId}) async {
    if (!available) {
      throw const StoreFailure('Purchases can be restored in the iPhone app.');
    }
    try {
      await _ensure();
      await Purchases.logIn(userId);
      await Purchases.restorePurchases();
    } on PlatformException {
      throw const StoreFailure("Couldn't reach the App Store. Try again.");
    }
  }
}

final storePurchasesProvider = Provider<StorePurchases>((ref) => StorePurchases());
