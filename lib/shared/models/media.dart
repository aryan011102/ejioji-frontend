import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';
import 'enums.dart';

/// A photo or video the server holds for us.
///
/// The URLs are signed and expire. They are signed per hour bucket on the
/// server, so the same photo keeps the same URL for at least an hour and the
/// image cache keeps working; [expiresAt] is when the current signature dies
/// and the owning screen should refetch rather than show a broken image.
@immutable
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.kind,
    required this.width,
    required this.height,
    required this.stillUrl,
    required this.expiresAt,
    this.videoUrl,
    this.videoDuration,
  });

  final String id;
  final MediaKind kind;
  final int width;
  final int height;
  final String stillUrl;
  final DateTime expiresAt;

  /// Present on a live photo (the motion half) and on a chat video.
  final String? videoUrl;
  final Duration? videoDuration;

  double get aspectRatio => height == 0 ? 1 : width / height;

  bool get hasMotion => videoUrl != null;

  bool get isStale => DateTime.now().isAfter(expiresAt);

  static MediaAsset fromJson(Json j) {
    final ms = j.intOrNull('video_duration_ms');
    return MediaAsset(
      id: j.str('id'),
      kind: MediaKind.parse(j.strOrNull('kind')),
      width: j.intOr('width', 0),
      height: j.intOr('height', 0),
      stillUrl: j.str('still_url'),
      videoUrl: j.strOrNull('video_url'),
      videoDuration: ms == null ? null : Duration(milliseconds: ms),
      expiresAt: j.time('urls_expire_at'),
    );
  }

  static List<MediaAsset> listFrom(List<Json> items) =>
      items.map(MediaAsset.fromJson).toList(growable: false);
}

/// Where to PUT the bytes of an upload, and with what headers.
///
/// The URL is a short-lived write-only signature for one blob name. Image
/// bytes never travel through our API on the way in.
@immutable
class UploadTarget {
  const UploadTarget({
    required this.method,
    required this.url,
    required this.headers,
  });

  final String method;
  final String url;
  final Map<String, String> headers;

  static UploadTarget fromJson(Json j) {
    final raw = j['headers'];
    return UploadTarget(
      method: j.strOrNull('method') ?? 'PUT',
      url: j.str('url'),
      headers: raw is Map
          ? raw.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }
}

/// The server's answer to "I want to upload this": an id to complete against,
/// and one target per half.
@immutable
class UploadTicket {
  const UploadTicket({
    required this.mediaId,
    required this.kind,
    required this.uploadBy,
    required this.completeBy,
    this.still,
    this.video,
  });

  final String mediaId;
  final MediaKind kind;
  final UploadTarget? still;
  final UploadTarget? video;

  /// The write signature dies here.
  final DateTime uploadBy;

  /// Past this the server sweeps the pending upload away.
  final DateTime completeBy;

  static UploadTicket fromJson(Json j) {
    final still = j.objectOrNull('still');
    final video = j.objectOrNull('video');
    return UploadTicket(
      mediaId: j.str('media_id'),
      kind: MediaKind.parse(j.strOrNull('kind')),
      still: still == null ? null : UploadTarget.fromJson(still),
      video: video == null ? null : UploadTarget.fromJson(video),
      uploadBy: j.time('upload_by'),
      completeBy: j.time('complete_by'),
    );
  }
}
