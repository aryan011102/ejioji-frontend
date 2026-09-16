import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/endpoints.dart';
import '../shared/models/enums.dart';
import '../shared/models/media.dart';

/// Photos and videos.
///
/// Bytes go straight to blob storage on a short-lived write-only URL the
/// server issues, and never travel through our API on the way in. The server
/// then reads the upload once and re-encodes it from pixels, which is what
/// removes the location a phone writes into a photo.
class MediaRepository {
  MediaRepository(this._api) : _blob = Dio();

  final ApiClient _api;

  /// A bare client for the blob write. It must not carry our bearer token: the
  /// upload URL is a third-party origin, and sending an Authorization header
  /// to one is how a credential leaves the app.
  final Dio _blob;

  Future<List<MediaAsset>> pool() async =>
      MediaAsset.listFrom(await _api.getList(Api.media));

  /// Uploads a still, and the motion half if this is a live photo.
  ///
  /// Three steps, in order: ask for a target, write the bytes, tell the server
  /// to process them. If the middle step fails the pending row is swept away
  /// on its own, so there is nothing to clean up here.
  Future<MediaAsset> upload({
    required Uint8List still,
    MediaKind kind = MediaKind.photo,
    Uint8List? video,
  }) async {
    final ticket = await _startUpload(
      kind: kind,
      stillBytes: still.length,
      videoBytes: video?.length,
    );

    await _write(ticket.still, still, 'still');
    if (video != null) await _write(ticket.video, video, 'video');

    return complete(ticket.mediaId);
  }

  /// For a chat photo or video, which is the same mechanism against a
  /// different ticket: the asset is tied to the conversation and never enters
  /// the profile pool.
  Future<MediaAsset> uploadToChat({
    required String matchId,
    required Uint8List bytes,
    required MediaKind kind,
  }) async {
    final body = await _api.post(
      Api.chatUpload(matchId),
      body: {
        'kind': kind == MediaKind.video ? 'video' : 'photo',
        'size_bytes': bytes.length,
      },
    );
    final ticket = UploadTicket.fromJson(body);

    await _write(
      kind == MediaKind.video ? ticket.video : ticket.still,
      bytes,
      kind == MediaKind.video ? 'video' : 'still',
    );

    return complete(ticket.mediaId);
  }

  Future<UploadTicket> _startUpload({
    required MediaKind kind,
    required int stillBytes,
    int? videoBytes,
  }) async {
    final body = await _api.post(
      Api.mediaUploads,
      body: {
        'kind': kind.wire,
        'still_bytes': stillBytes,
        if (videoBytes != null) 'video_bytes': videoBytes,
      },
    );
    return UploadTicket.fromJson(body);
  }

  /// Turns the uploaded bytes into an asset. This is where the server reads,
  /// re-encodes and deletes the original, so it is slower than it looks.
  Future<MediaAsset> complete(String mediaId) async =>
      MediaAsset.fromJson(await _api.post(Api.mediaComplete(mediaId)));

  /// Deletes the asset and its blobs. A photo on the profile comes off it in
  /// the same transaction.
  Future<void> delete(String mediaId) =>
      _api.deleteEmpty(Api.mediaItem(mediaId));

  Future<void> _write(UploadTarget? target, Uint8List bytes, String half) async {
    if (target == null) {
      throw UnknownFailure(debugDetail: 'no $half upload target was issued');
    }
    try {
      await _blob.requestUri<void>(
        Uri.parse(target.url),
        data: Stream.value(bytes),
        options: Options(
          method: target.method,
          headers: {
            ...target.headers,
            Headers.contentLengthHeader: bytes.length,
          },
          // The signature is write-only and short-lived, so a slow connection
          // is the realistic failure here rather than a refusal.
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }
}
