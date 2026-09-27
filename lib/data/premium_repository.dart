import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../shared/models/premium.dart';

/// Premium: what is on offer, whether you have it, and starting it.
///
/// There is no payment yet (no Razorpay), so starting a plan is free and the
/// server records it at ₹0. When prices exist this is where the payment step
/// goes; the server still decides whether it went through.
class PremiumRepository {
  const PremiumRepository(this._api);

  final ApiClient _api;

  Future<PremiumStatus> status() async =>
      PremiumStatus.fromJson(await _api.getJson(Api.premium));

  /// 409 `premium_active` while a plan is still running: a second free plan
  /// on top of the first is not something to hand out before prices exist.
  Future<PremiumStatus> start(String plan) async => PremiumStatus.fromJson(
        await _api.post(Api.premiumPurchases, body: {'plan': plan}),
      );
}
