import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../data/tile_media_controller.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/media.dart';
import '../../../shared/models/tile.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';

/// Answering one question, on its own screen: Cancel, Done, the question in
/// full, what the person writes, and somewhere to put a photo or video behind
/// it.
///
/// Saving happens here rather than on the way out of the category screen, for
/// two reasons. The server refuses an answer carrying contact details, and that
/// refusal has to land on the words that caused it. And a photo can only go
/// behind a tile that exists, so the answer must be written before the camera
/// is any use.
///
/// Returns true when something was saved.
Future<bool> showAnswerSheet(
  BuildContext context, {
  required Prompt prompt,
  PromptAnswer? existing,
}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AnswerSheet(prompt: prompt, existing: existing),
    ),
  );
  return saved ?? false;
}

class _AnswerSheet extends ConsumerStatefulWidget {
  const _AnswerSheet({required this.prompt, this.existing});

  final Prompt prompt;
  final PromptAnswer? existing;

  @override
  ConsumerState<_AnswerSheet> createState() => _AnswerSheetState();
}

class _AnswerSheetState extends ConsumerState<_AnswerSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.prompt.kind == AnswerKind.text
        ? widget.existing?.answer ?? ''
        : '',
  );
  late String? _option = widget.existing?.option;

  /// True once this screen has written the answer, so leaving by Cancel
  /// afterwards still reports what was saved rather than pretending nothing
  /// happened.
  bool _saved = false;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _isText => widget.prompt.kind == AnswerKind.text;

  bool get _filled => _isText ? _text.text.trim().isNotEmpty : _option != null;

  /// Writes the answer. Returns false and says why if the server refuses it.
  Future<bool> _save() async {
    if (!_filled) return _saved;
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).answer(
            widget.prompt.key,
            text: _isText ? _text.text.trim() : null,
            option: _isText ? null : _option,
          );
      ref.invalidate(promptBankProvider);
      _saved = true;
      return true;
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _done() async {
    if (!await _save()) return;
    if (mounted) Navigator.of(context).pop(true);
  }

  /// The camera. The answer is written first: the server only puts media
  /// behind a tile that exists, and an unanswered question is not one yet.
  Future<void> _media({required bool hasMedia}) async {
    if (!_saved && !await _save()) return;
    if (!mounted) return;

    final taken = await showAppActionSheet(
      context,
      title: 'Put something behind this answer',
      message: 'It sits under your words, on your profile only while this '
          'answer is picked.',
      actions: [
        const SheetAction('Photo Library', icon: Icons.photo_library_outlined),
        const SheetAction('Take Photo or Video', icon: Icons.photo_camera),
        const SheetAction('Choose File', icon: Icons.folder_outlined),
        if (hasMedia) const SheetAction('Remove', destructive: true),
      ],
    );
    if (taken == null || !mounted) return;

    void onError(String message) {
      if (mounted) showAppToast(context, message);
    }

    final controller = ref.read(tileMediaProvider.notifier);
    if (taken == 3) {
      await controller.clear(
        TileKind.prompt,
        widget.prompt.key,
        onError: onError,
      );
      return;
    }
    await controller.attach(
      TileKind.prompt,
      widget.prompt.key,
      TileMediaSource.values[taken],
      onError: onError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(tileMediaProvider);
    final fromServer = <String, MediaAsset>{
      for (final e in ref.watch(tileMediaListProvider).valueOrNull ??
          const <TileMediaEntry>[])
        TileMedia.id(e.kind, e.key): e.media,
    };
    final behind = media.resolve(
      TileKind.prompt,
      widget.prompt.key,
      fromServer[TileMedia.id(TileKind.prompt, widget.prompt.key)],
    );
    final busy = media.isBusy(TileKind.prompt, widget.prompt.key);

    return AppScaffold(
      navBar: AppNavBar(
        leadingLabel: 'Cancel',
        onLeading: () => Navigator.of(context).pop(_saved),
        trailingLabel: 'Done',
        trailingEnabled: _filled && !_saving,
        onTrailing: _done,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.titleGutter,
          6,
          Insets.titleGutter,
          24,
        ),
        children: [
          Text(widget.prompt.text, style: AppText.title1.copyWith(fontSize: 24)),
          const SizedBox(height: 16),
          if (_isText) _field() else ..._options(),
          const SizedBox(height: 14),
          _mediaRow(behind: behind, busy: busy),
        ],
      ),
    );
  }

  Widget _field() {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(Radii.row)),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: _text,
      autofocus: true,
      minLines: 3,
      maxLines: 4,
      // The server holds the same number, so a longer answer would be refused
      // after it was typed rather than while.
      maxLength: widget.prompt.maxChars,
      textCapitalization: TextCapitalization.sentences,
      style: AppText.body.copyWith(fontSize: 16),
      cursorColor: AppColors.accent,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        counterText: '',
        hintText: 'In your own words.',
        hintStyle: AppText.body.copyWith(fontSize: 16, color: AppColors.label3),
        filled: true,
        fillColor: AppColors.row,
        contentPadding: const EdgeInsets.all(14),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }

  List<Widget> _options() => [
        for (final option in widget.prompt.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Pressable(
              onTap: () => setState(() => _option = option.key),
              semanticLabel: option.label,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.row,
                  borderRadius: BorderRadius.circular(Radii.row),
                  border: Border.all(
                    color: _option == option.key
                        ? AppColors.accent
                        : AppColors.glassEdge,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(option.label, style: AppText.body)),
                    if (_option == option.key)
                      const Icon(
                        Icons.check_circle,
                        size: 20,
                        color: AppColors.accent,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ];

  Widget _mediaRow({required MediaAsset? behind, required bool busy}) {
    final has = behind != null;
    return Pressable(
      onTap: busy ? null : () => _media(hasMedia: has),
      semanticLabel:
          has ? 'Change what is behind this answer' : 'Add a photo or video',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.row,
          borderRadius: BorderRadius.circular(Radii.row),
          border: Border.all(color: AppColors.glassEdge),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.photo_camera,
                size: 18,
                color: AppColors.label,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    has ? _behindLabel(behind) : 'Add a photo or video',
                    style: AppText.body,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    busy
                        ? 'Uploading...'
                        : 'Optional. It sits behind the answer.',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.label3),
          ],
        ),
      ),
    );
  }

  String _behindLabel(MediaAsset behind) => switch (behind.kind) {
        MediaKind.video => 'Video attached',
        MediaKind.livePhoto => 'Live photo attached',
        _ => 'Photo attached',
      };
}
