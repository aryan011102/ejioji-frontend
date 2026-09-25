import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../shared/models/connection.dart';

/// Where a person's verification stands, as the server works it out now.
///
/// The server derives the tick from the profile on every read, so an edited
/// first name or birth date shows here as [VerificationStatus.outdated] with
/// nothing for the app to clear.
enum VerificationStatus {
  none('none'),
  verified('verified'),
  outdated('outdated'),
  revoked('revoked');

  const VerificationStatus(this.wire);

  final String wire;

  static VerificationStatus parse(String? raw) => values.firstWhere(
        (v) => v.wire == raw,
        orElse: () => VerificationStatus.none,
      );
}

@immutable
class Verification {
  const Verification({
    required this.status,
    required this.available,
    this.verifiedAt,
  });

  final VerificationStatus status;

  /// False while the server has no DigiLocker client configured.
  final bool available;
  final DateTime? verifiedAt;

  bool get verified => status == VerificationStatus.verified;

  static Verification fromJson(Json j) => Verification(
        status: VerificationStatus.parse(j.strOrNull('status')),
        available: j.flag('available'),
        verifiedAt: j.timeOrNull('verified_at'),
      );
}

/// What one DigiLocker check came to. [outcome] is `verified`, `declined`, or
/// the reason it was refused; [message] is the server's own words for it.
@immutable
class VerificationResult {
  const VerificationResult({
    required this.outcome,
    required this.verified,
    required this.message,
  });

  final String outcome;
  final bool verified;
  final String message;

  bool get declined => outcome == 'declined';

  static VerificationResult fromJson(Json j) => VerificationResult(
        outcome: j.str('outcome'),
        verified: j.flag('verified'),
        message: j.str('message'),
      );
}

class VerificationRepository {
  const VerificationRepository(this._api);

  final ApiClient _api;

  Future<Verification> load() async =>
      Verification.fromJson(await _api.getJson(Api.verification));

  /// A 403 `consent_required` until identity_verification is granted, a 422
  /// with no profile yet, a 503 when DigiLocker is not set up on this server.
  Future<Authorization> authorize() async =>
      Authorization.fromJson(await _api.post(Api.digilockerAuthorize));

  /// What DigiLocker put on the redirect. The state is bound to this person
  /// and used once; the server exchanges the code, compares, and forgets.
  Future<VerificationResult> complete({
    required String state,
    String? code,
    String? error,
  }) async {
    final body = await _api.post(
      Api.digilockerComplete,
      body: {
        'state': state,
        if (code != null) 'code': code,
        if (error != null) 'error': error,
      },
    );
    return VerificationResult.fromJson(body);
  }
}
