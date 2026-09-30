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

  /// Matching is granted at setup without a screen (Aryan, 2026-09-30).
  ///
  /// Only for someone who has never answered it: a grant that was withdrawn
  /// stays withdrawn, and the screen in Settings is still the way back. Quiet
  /// on failure, because the feed asks again if it is still missing.
  Future<void> grantMatchingIfNeverAsked() async {
    try {
      final state = await load();
      final asked =
          state.grants.any((g) => g.purpose == ConsentPurpose.matching);
      final notice = state.noticeFor(ConsentPurpose.matching);
      if (asked || notice == null) return;
      await grant({ConsentPurpose.matching: notice.version});
    } on Exception {
      return;
    }
  }

  /// Grants [purpose] at the current notice unless it is already open. For a
  /// step the person has just chosen to take, where a permission screen of its
  /// own was cut (DigiLocker, Aryan, 2026-09-30).
  Future<void> grantNow(ConsentPurpose purpose) async {
    final state = await load();
    if (state.isGranted(purpose)) return;
    final notice = state.noticeFor(purpose);
    if (notice == null) return;
    await grant({purpose: notice.version});
  }

  /// Withdrawal reaches the data in the same transaction: revoking a source
  /// purges what it produced, not just the link. There is nothing for the
  /// client to clean up afterwards beyond refetching.
  Future<void> revoke(ConsentPurpose purpose) =>
      _api.postEmpty(Api.consentRevoke, body: {'purpose': purpose.wire});
}
