import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/network/api_exception.dart';
import '../shared/models/media.dart';
import 'providers.dart';

/// The photo pool, and adding to it.
///
/// Uploading is three round trips and a picker, and several screens need it,
/// so it lives here rather than being written out again on each one.
///
/// The bytes go straight to blob storage on a signed, write-only URL that is
/// good for one blob name and ten minutes. They never pass through our API.
/// The server then reads the upload once and re-encodes it from pixels: not
/// stripping tags, re-encoding, because knowing every place a camera hides a
/// location (EXIF, XMP, IPTC, maker notes) is a losing game, and a live photo
/// carries GPS in a binary box whose digits never appear as text.
@immutable
class PhotoPool {
  const PhotoPool({
    this.assets = const [],
    this.uploading = false,
    this.loading = true,
  });

  final List<MediaAsset> assets;
  final bool uploading;
  final bool loading;

  PhotoPool copyWith({
    List<MediaAsset>? assets,
    bool? uploading,
    bool? loading,
  }) =>
      PhotoPool(
        assets: assets ?? this.assets,
        uploading: uploading ?? this.uploading,
        loading: loading ?? this.loading,
      );
}

class PhotoController extends Notifier<PhotoPool> {
  /// The pool holds twelve, pending uploads included; a profile shows six.
  static const maxPhotos = 12;

  final _picker = ImagePicker();

  @override
  PhotoPool build() {
    Future.microtask(load);
    return const PhotoPool();
  }

  Future<void> load() async {
    try {
      final assets = await ref.read(mediaRepositoryProvider).pool();
      state = state.copyWith(assets: assets, loading: false);
    } on ApiException {
      state = state.copyWith(loading: false);
    }
  }

  /// Picks one photo and uploads it.
  ///
  /// HEIC is converted by the picker before we see it, which is deliberate:
  /// the fewer image decoders that parse untrusted bytes in a process holding
  /// database credentials, the better.
  Future<void> add({required void Function(String) onError}) async {
    if (state.uploading || state.assets.length >= maxPhotos) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      // The server shrinks to 1600px on the long side anyway. Handing it
      // something closer to that saves the person's data allowance without
      // costing anything visible.
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    if (picked == null) return;

    state = state.copyWith(uploading: true);
    try {
      final bytes = await picked.readAsBytes();
      final asset =
          await ref.read(mediaRepositoryProvider).upload(still: bytes);
      state = state.copyWith(assets: [...state.assets, asset]);
      ref.invalidate(mediaPoolProvider);
    } on ApiException catch (e) {
      onError(e.message);
    } finally {
      state = state.copyWith(uploading: false);
    }
  }

  /// Deletes the asset and its blobs. A photo on the profile comes off it in
  /// the same transaction, which can drop a profile below the two it needs and
  /// stop it showing. That is correct, and the profile screen says so.
  Future<void> remove(
    String mediaId, {
    required void Function(String) onError,
  }) async {
    try {
      await ref.read(mediaRepositoryProvider).delete(mediaId);
      state = state.copyWith(
        assets: [
          for (final a in state.assets)
            if (a.id != mediaId) a,
        ],
      );
      ref
        ..invalidate(mediaPoolProvider)
        ..invalidate(myProfileProvider);
    } on ApiException catch (e) {
      onError(e.message);
    }
  }

  /// Sets which photos are on the profile, and in what order.
  Future<void> setOnProfile(
    List<String> mediaIds, {
    required void Function(String) onError,
  }) async {
    try {
      await ref.read(profileRepositoryProvider).setPhotos(mediaIds);
      ref.invalidate(myProfileProvider);
    } on ApiException catch (e) {
      onError(e.message);
    }
  }
}

final photoPoolProvider =
    NotifierProvider<PhotoController, PhotoPool>(PhotoController.new);
