import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../shared/models/connection.dart';
import '../shared/models/enums.dart';

/// Where one check stands, as the server works it out now.
///
/// The server derives the tick from the profile on every read, so an edited
/// first name or birth date (DigiLocker), or a new photo (the selfie), shows
/// here as [VerificationStatus.outdated] with nothing for the app to clear.
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

/// One check: DigiLocker's (the top level of the server's answer) or the
/// selfie's (its `selfie` object). Both have the same shape.
@immutable
class Check {
  const Check({
    required this.status,
    required this.available,
    this.verifiedAt,
  });

  static const none = Check(status: VerificationStatus.none, available: false);

  final VerificationStatus status;

  /// False while the server has this check switched off.
  final bool available;
  final DateTime? verifiedAt;

  bool get verified => status == VerificationStatus.verified;

  static Check fromJson(Json j) => Check(
        status: VerificationStatus.parse(j.strOrNull('status')),
        available: j.flag('available'),
        verifiedAt: j.timeOrNull('verified_at'),
      );
}

/// Both checks, and the tick they come to together.
@immutable
class Verification {
  const Verification({
    required this.digilocker,
    required this.selfie,
    required this.tier,
  });

  final Check digilocker;
  final Check selfie;
  final VerificationTier tier;

  bool get verified => tier.verified;

  /// A server from before the selfie sends DigiLocker's half alone: no
  /// selfie, and the tick is DigiLocker's.
  static Verification fromJson(Json j) {
    final digilocker = Check.fromJson(j);
    final selfie = j.objectOrNull('selfie');
    return Verification(
      digilocker: digilocker,
      selfie: selfie == null ? Check.none : Check.fromJson(selfie),
      tier: VerificationTier.parse(
        j.strOrNull('tier'),
        verified: digilocker.verified,
      ),
    );
  }
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

/// What one selfie came to. [outcome] is `verified` or the reason it was
/// refused; [message] is the server's own words for it. [differingPhotoIds]
/// are the profile photos whose face is not the selfie's.
@immutable
class SelfieResult {
  const SelfieResult({
    required this.outcome,
    required this.verified,
    required this.message,
    required this.tier,
    this.differingPhotoIds = const [],
  });

  final String outcome;
  final bool verified;
  final String message;
  final VerificationTier tier;
  final List<String> differingPhotoIds;

  /// Refusals a photo change fixes, as against a better selfie.
  bool get aboutPhotos => const {
        'no_photos',
        'no_face_in_photos',
        'photos_differ',
      }.contains(outcome);

  static SelfieResult fromJson(Json j) => SelfieResult(
        outcome: j.str('outcome'),
        verified: j.flag('verified'),
        message: j.str('message'),
        tier: VerificationTier.parse(
          j.strOrNull('tier'),
          verified: j.flag('verified'),
        ),
        differingPhotoIds: j.strings('differing_photo_ids'),
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

  /// A 403 `consent_required` until selfie_verification is granted, a 422
  /// `selfie_unreadable` for something that is not a photo, a 429 past the
  /// day's attempts, a 503 when the server has no Rekognition keys, a 502
  /// when Rekognition does not answer. The server compares the selfie with
  /// every profile photo, so it is given longer than a plain request.
  Future<SelfieResult> checkSelfie(List<int> jpeg) async {
    final body = await _api.postFile(
      Api.selfie,
      field: 'photo',
      bytes: jpeg,
      filename: 'selfie.jpg',
      contentType: 'image/jpeg',
      receiveTimeout: const Duration(seconds: 60),
    );
    return SelfieResult.fromJson(body);
  }
}
