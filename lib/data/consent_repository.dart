import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/storage/device.dart';
import '../shared/models/consent.dart';
import '../shared/models/enums.dart';

/// Consent, which is a table rather than a checkbox.
///
/// Six purposes: one per source, plus `ai_processing` for what leaves our
/// infrastructure and `matching` for the fact that hidden tiles still inform
/// who a person is shown. Each is separately grantable and separately
/// revocable, and the server refuses to connect a source whose purpose is not
/// open.
class ConsentRepository {
  const ConsentRepository(this._api, this._device);

  final ApiClient _api;
  final DeviceIdentity _device;

  /// The published notices. These carry the actual text a person agrees to,
  /// so the screen renders the server's copy rather than its own.
  Future<List<ConsentNotice>> notices() async =>
      ConsentNotice.listFrom(await _api.getList(Api.consentNotices));

  Future<List<ConsentGrant>> grants() async =>
      ConsentGrant.listFrom(await _api.getList(Api.consentGrants));

  /// Both halves, for the screen that shows them together.
  Future<ConsentState> load() async {
    final results = await Future.wait([notices(), grants()]);
    return ConsentState(
      notices: results[0] as List<ConsentNotice>,
      grants: results[1] as List<ConsentGrant>,
    );
  }

  /// Grants one or more purposes at the version the client was shown.
  ///
  /// The version is sent, never a hash: the server computes the hash of its
  /// own published text, because a hash the client supplied would be a claim
  /// rather than evidence.
  Future<List<ConsentGrant>> grant(Map<ConsentPurpose, int> purposes) async {
    final body = await _api.postList(
      Api.consentGrants,
      body: {
        'grants': [
          for (final e in purposes.entries)
            {'purpose': e.key.wire, 'version': e.value},
        ],
        'device_key': await _device.key(),
      },
    );
    return ConsentGrant.listFrom(body);
  }

  /// Withdrawal reaches the data in the same transaction: revoking a source
  /// purges what it produced, not just the link. There is nothing for the
  /// client to clean up afterwards beyond refetching.
  Future<void> revoke(ConsentPurpose purpose) =>
      _api.postEmpty(Api.consentRevoke, body: {'purpose': purpose.wire});
}
