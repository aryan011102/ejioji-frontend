import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../shared/models/premium.dart';

/// Premium: what is on offer, whether you have it, and starting it.
///
/// Two ways in. While the server says `free_for_now`, [start] grants a plan
/// for nothing. Once prices are live a plan is bought in the App Store
/// (`core/purchases`), and [sync] asks the server to check the store and
/// answer with what it found. Either way the server decides.
class PremiumRepository {
  const PremiumRepository(this._api);

  final ApiClient _api;

  Future<PremiumStatus> status() async =>
      PremiumStatus.fromJson(await _api.getJson(Api.premium));

  /// 409 `premium_active` while a plan is still running: a second free plan
  /// on top of the first is not something to hand out before prices exist.
  /// 403 `free_plans_ended` once plans are bought in the App Store.
  Future<PremiumStatus> start(String plan) async => PremiumStatus.fromJson(
        await _api.post(Api.premiumPurchases, body: {'plan': plan}),
      );

  /// After an App Store purchase or restore: the server reads the store and
  /// says what this person holds now.
  Future<PremiumStatus> sync() async =>
      PremiumStatus.fromJson(await _api.post(Api.premiumSync));
}
