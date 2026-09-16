import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';
import 'enums.dart';

/// A consent notice, as published.
///
/// The text lives in the backend repository and is hash-locked once published,
/// so the wording has a git history and the hash on a grant is evidence rather
/// than a claim. The client never computes or sends that hash.
@immutable
class ConsentNotice {
  const ConsentNotice({
    required this.purpose,
    required this.version,
    required this.sha256,
    required this.draft,
    required this.body,
  });

  final ConsentPurpose purpose;
  final int version;
  final String sha256;

  /// True while the copy is placeholder text. Production refuses to boot on
  /// a draft, so seeing one means this build points at development.
  final bool draft;

  final String body;

  static ConsentNotice fromJson(Json j) => ConsentNotice(
        purpose: ConsentPurpose.parse(j.strOrNull('purpose')),
        version: j.intOr('version', 1),
        sha256: j.str('sha256'),
        draft: j.flag('draft'),
        body: j.str('body'),
      );

  static List<ConsentNotice> listFrom(List<Json> items) =>
      items.map(ConsentNotice.fromJson).toList(growable: false);
}

/// One grant, open or closed.
///
/// Grants are append-only at the database: revoking closes a row rather than
/// editing it, so the history is the audit trail.
@immutable
class ConsentGrant {
  const ConsentGrant({
    required this.id,
    required this.purpose,
    required this.noticeVersion,
    required this.grantedAt,
    required this.active,
    this.revokedAt,
    this.revocationReason,
  });

  final String id;
  final ConsentPurpose purpose;
  final int noticeVersion;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final String? revocationReason;
  final bool active;

  static ConsentGrant fromJson(Json j) => ConsentGrant(
        id: j.str('id'),
        purpose: ConsentPurpose.parse(j.strOrNull('purpose')),
        noticeVersion: j.intOr('notice_version', 1),
        grantedAt: j.time('granted_at'),
        revokedAt: j.timeOrNull('revoked_at'),
        revocationReason: j.strOrNull('revocation_reason'),
        active: j.flag('active'),
      );

  static List<ConsentGrant> listFrom(List<Json> items) =>
      items.map(ConsentGrant.fromJson).toList(growable: false);
}

/// The notices and the person's answers, held together.
@immutable
class ConsentState {
  const ConsentState({required this.notices, required this.grants});

  final List<ConsentNotice> notices;
  final List<ConsentGrant> grants;

  bool isGranted(ConsentPurpose purpose) =>
      grants.any((g) => g.purpose == purpose && g.active);

  ConsentNotice? noticeFor(ConsentPurpose purpose) {
    for (final n in notices) {
      if (n.purpose == purpose) return n;
    }
    return null;
  }

  /// A source cannot be connected without this, and the server will refuse the
  /// authorize call rather than fail later.
  bool canConnect(Provider provider) => isGranted(provider.purpose);
}
