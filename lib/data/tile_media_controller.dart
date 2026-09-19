import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/network/api_exception.dart';
import '../shared/models/enums.dart';
import '../shared/models/media.dart';
import 'providers.dart';

/// Where the thing behind a tile comes from. The three rows of the sheet.
enum TileMediaSource { library, camera, file }

/// What sits behind each tile, as this session has changed it.
///
/// The server's copy arrives on the profile's tiles and, for the picker, from
/// GET /profile/tiles/media. This holds only what was
/// changed since, so a new photo shows the moment it lands rather than after
/// the candidates and the profile are both pulled again — and so the same
/// tile looks the same on the picker, the wall and arrange mode meanwhile.
@immutable
class TileMedia {
  const TileMedia({this.changed = const {}, this.busy = const {}});

  /// A null value means it was taken off.
  final Map<String, MediaAsset?> changed;

  /// Tiles with an upload in flight.
  final Set<String> busy;

  static String id(TileKind kind, String key) => '${kind.wire}:$key';

  bool isBusy(TileKind kind, String key) => busy.contains(id(kind, key));

  /// This session's change if there is one, otherwise what the server sent.
  MediaAsset? resolve(TileKind kind, String key, MediaAsset? fromServer) {
    final k = id(kind, key);
    return changed.containsKey(k) ? changed[k] : fromServer;
  }
}

class TileMediaController extends Notifier<TileMedia> {
  /// Past this a video is refused before it is read into memory whole. The
  /// server refuses anything over a minute anyway, so a bigger file is a data
  /// bill that ends in an error.
  static const maxVideoBytes = 60 * 1024 * 1024;

  static const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv'};

  final _picker = ImagePicker();

  @override
  TileMedia build() => const TileMedia();

  /// Picks from [source] and puts it behind the tile. A cancelled picker is
  /// not an error and says nothing.
  Future<void> attach(
    TileKind kind,
    String key,
    TileMediaSource source, {
    required void Function(String) onError,
  }) async {
    final id = TileMedia.id(kind, key);
    if (state.busy.contains(id)) return;

    final picked = await _pick(source);
    if (picked == null) return;

    _setBusy(id, true);
    try {
      final size = await picked.length();
      if (picked.isVideo && size > maxVideoBytes) {
        onError('That video is too long. Keep it under a minute or so.');
        return;
      }
      final bytes = await picked.bytes();
      final uploaded = await ref
          .read(mediaRepositoryProvider)
          .uploadForTile(bytes, video: picked.isVideo);
      final asset = await ref
          .read(profileRepositoryProvider)
          .setTileMedia(kind, key, uploaded.id);
      state = TileMedia(
        changed: {...state.changed, id: asset},
        busy: state.busy,
      );
      ref
        ..invalidate(myProfileProvider)
        ..invalidate(tileMediaListProvider);
    } on ApiException catch (e) {
      onError(e.message);
    } finally {
      _setBusy(id, false);
    }
  }

  Future<void> clear(
    TileKind kind,
    String key, {
    required void Function(String) onError,
  }) async {
    final id = TileMedia.id(kind, key);
    if (state.busy.contains(id)) return;

    _setBusy(id, true);
    try {
      await ref.read(profileRepositoryProvider).clearTileMedia(kind, key);
      state = TileMedia(
        changed: {...state.changed, id: null},
        busy: state.busy,
      );
      ref
        ..invalidate(myProfileProvider)
        ..invalidate(tileMediaListProvider);
    } on ApiException catch (e) {
      onError(e.message);
    } finally {
      _setBusy(id, false);
    }
  }

  void _setBusy(String id, bool on) => state = TileMedia(
        changed: state.changed,
        busy: on ? {...state.busy, id} : ({...state.busy}..remove(id)),
      );

  Future<_Picked?> _pick(TileMediaSource source) async {
    switch (source) {
      case TileMediaSource.library:
        // Photos and videos in one grid. A Live Photo comes back as its
        // still: the picker does not hand over the motion half.
        final x = await _picker.pickMedia(
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 92,
        );
        return x == null ? null : _Picked.xfile(x, _isVideo(x.name, x.mimeType));
      case TileMediaSource.camera:
        final x = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 92,
        );
        return x == null ? null : _Picked.xfile(x, false);
      case TileMediaSource.file:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.media,
          withData: true,
        );
        final f = result?.files.singleOrNull;
        if (f == null || f.bytes == null) return null;
        return _Picked.bytes(f.bytes!, _isVideo(f.name, null));
    }
  }

  static bool _isVideo(String name, String? mime) {
    if (mime != null) return mime.startsWith('video/');
    final dot = name.lastIndexOf('.');
    return dot >= 0 &&
        _videoExtensions.contains(name.substring(dot + 1).toLowerCase());
  }
}

/// One picked file, from either picker.
class _Picked {
  _Picked.xfile(XFile file, this.isVideo)
      : _file = file,
        _bytes = null;
  _Picked.bytes(Uint8List bytes, this.isVideo)
      : _file = null,
        _bytes = bytes;

  final XFile? _file;
  final Uint8List? _bytes;
  final bool isVideo;

  Future<int> length() async => _bytes?.length ?? await _file!.length();
  Future<Uint8List> bytes() async => _bytes ?? await _file!.readAsBytes();
}

final tileMediaProvider =
    NotifierProvider<TileMediaController, TileMedia>(TileMediaController.new);
