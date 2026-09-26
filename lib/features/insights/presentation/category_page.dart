import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../data/tile_media_controller.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/media.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/tile.dart';
import '../../../shared/models/tile_look.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/tiles.dart';
import 'answer_sheet.dart';

/// The categories the picker walks through, in a fixed order: every category
/// with at least one computed tile or one answer, plus every category the bank
/// asks about. An asked category is in the walk even when it holds nothing,
/// because holding nothing is precisely when its questions are shown. Order
/// follows the enum, so an index means the same category on the way in and on
/// the way back.
List<TileCategory> pickableCategories(
  List<Insight> candidates,
  List<PromptAnswer> answers,
  PromptBank bank,
) =>
    [
      for (final c in TileCategory.values)
        if (c != TileCategory.unknown &&
            (bank.askedCategories.contains(c) ||
                candidates.any((i) => i.category == c) ||
                answers.any((a) => a.category == c)))
          c,
    ];

/// The categories one app's tiles land in, in the same order as the full walk.
///
/// A walk opened with a source is that app's categories rather than every
/// category, so Gmail steps food delivery, going out, travel and moving and
/// stops, without wandering into Netflix. Edit tiles walks every category.
List<TileCategory> categoriesOf(
  SourceProvider source,
  List<Insight> candidates,
  List<TileCategory> categories,
) =>
    [
      for (final c in categories)
        if (candidates.any((i) => i.category == c && i.providers.contains(source))) c,
    ];

/// One category of tiles, on the way in and on the way back.
///
/// Editing is this screen re-entered, not a different one. Three things differ
/// in [editing]:
///
///  * the heading says where you are rather than what to do,
///  * the foot saves as it goes, and the last one returns to the connect
///    screen instead of going on to the profile review,
///  * the setup progress bar is hidden.
///
/// What is on the profile is one ordered list on the server. Saving a category
/// replaces that category's tiles in the list and leaves every other one where
/// the person put it.
class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({
    required this.index,
    required this.editing,
    this.source,
    super.key,
  });

  final int index;
  final bool editing;

  /// Set when this was opened from one app's card, which makes the walk that
  /// app's categories instead of all of them. [index] counts within the walk.
  final SourceProvider? source;

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

/// A choice on this screen: an insight or an answer, by its key.
typedef _Choice = ({TileKind kind, String key});

class _CategoryPageState extends ConsumerState<CategoryPage> {
  /// The server's rules too: two to a category, so every category gets a
  /// turn, and ten on the profile in all. Photos are not tiles and do not
  /// count.
  static const _perCategory = 2;
  static const _maxTiles = 10;

  Set<_Choice>? _picked;

  /// Tiles on the profile from every other category, which count toward
  /// [_maxTiles] alongside what is picked here. Set on each build.
  int _elsewhere = 0;

  /// Why the last tap added nothing, shown for a moment at the foot.
  String? _capNote;
  bool _saving = false;

  void _toggle(_Choice choice) {
    final picked = _picked!;
    String? note;
    setState(() {
      if (picked.remove(choice)) return;
      if (picked.length >= _perCategory) {
        note = 'Two to a category, so every category gets a turn. Drop one '
            'to swap it.';
      } else if (_elsewhere + picked.length >= _maxTiles) {
        note = 'Ten tiles is the most a profile shows. Drop one here or in '
            'another category to add this.';
      } else {
        picked.add(choice);
      }
      _capNote = note;
    });
    if (note != null) {
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (mounted && _capNote == note) setState(() => _capNote = null);
      });
    }
  }

  /// Replaces this category's tiles in the profile's list. Tiles already on
  /// the profile keep their place; new ones go to the end.
  Future<void> _save(TileCategory category, List<ProfileTile> current) async {
    final picked = _picked!;
    final keep = [
      for (final t in current)
        if (t.category != category || picked.contains((kind: t.kind, key: t.key))) t,
    ];
    final present = {for (final t in keep) (kind: t.kind, key: t.key)};
    final tiles = [
      for (final t in keep) t.toRef(),
      for (final c in picked)
        if (!present.contains(c)) {'kind': c.kind.wire, 'key': c.key},
    ];
    await ref.read(profileRepositoryProvider).setTileRefs(tiles);
    ref.invalidate(myProfileProvider);
  }

  Future<void> _next(
    TileCategory category,
    List<ProfileTile> current,
    int count,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _save(category, current);
      if (!mounted) return;
      if (widget.editing) {
        _leave(count);
        return;
      }
      _advance(count);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Where saving goes in edit mode: on to the next category, and at the end
  /// back to the connect screen the walk started from. Every step of the walk
  /// was pushed, so the way back is one pop per step, which leaves the connect
  /// screen with its own back button to the profile.
  void _leave(int count) {
    if (widget.index >= count - 1) {
      final nav = Navigator.of(context);
      for (var i = 0; i <= widget.index; i++) {
        nav.pop();
      }
      return;
    }
    unawaited(
      context.push<void>(
        Routes.editCategoryAt(widget.index + 1, source: widget.source),
      ),
    );
  }

  void _advance(int count) {
    final last = widget.index >= count - 1;
    unawaited(
      context.push<void>(
        last ? Routes.profileReview : Routes.pickCategoryAt(widget.index + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(candidatesProvider);
    final profile = ref.watch(myProfileProvider);
    final bank = ref.watch(promptBankProvider);
    final media = ref.watch(tileMediaProvider);
    final saved = <String, MediaAsset>{
      for (final e in ref.watch(tileMediaListProvider).valueOrNull ??
          const <TileMediaEntry>[])
        TileMedia.id(e.kind, e.key): e.media,
    };
    final all = [candidates, profile, bank];
    final failed = all.where((a) => a.hasError).firstOrNull;

    if (failed != null || all.any((a) => !a.hasValue)) {
      return AppScaffold(
        navBar: AppNavBar(backLabel: 'Back', onBack: () => context.pop()),
        child: failed != null
            ? ErrorView(
                error: failed.error!,
                onRetry: () => ref
                  ..invalidate(candidatesProvider)
                  ..invalidate(myProfileProvider)
                  ..invalidate(promptBankProvider),
              )
            : const LoadingView(),
      );
    }

    final insights = candidates.requireValue;
    final answers = bank.requireValue.answers;
    final current = profile.requireValue.tiles;
    final walkable = pickableCategories(insights, answers, bank.requireValue);
    final source = widget.source;
    final categories =
        source == null ? walkable : categoriesOf(source, insights, walkable);

    if (widget.index >= categories.length) {
      return AppScaffold(
        navBar: AppNavBar(backLabel: 'Back', onBack: () => context.pop()),
        child: EmptyState(
          icon: Icons.grid_view_rounded,
          title: 'Nothing to pick from yet',
          body: 'Connect an app or answer a question, and your tiles appear '
              'here.',
          primaryLabel: 'Connect an app',
          // In edit mode the connect screen is the one this walk came from.
          onPrimary: () => widget.editing
              ? context.pop()
              : context.push(Routes.connect),
        ),
      );
    }

    final category = categories[widget.index];
    _picked ??= {
      for (final t in current)
        if (t.category == category) (kind: t.kind, key: t.key),
    };
    final picked = _picked!;
    _elsewhere = current.where((t) => t.category != category).length;
    final inCategory = insights.where((i) => i.category == category).toList();
    final answered = answers.where((a) => a.category == category).toList();
    // Thin: their data could not fill this category, so we ask instead. The
    // questions are rows rather than tiles in the grid, so an answer reads as
    // a question answered and never as something we worked out.
    final asking = bank.requireValue.asks(category, inCategory.length);
    final questions =
        asking ? bank.requireValue.inCategory(category) : const <Prompt>[];

    return AppScaffold(
      navBar: AppNavBar(
        backLabel: 'Back',
        onBack: () => context.pop(),
        trailingLabel: !widget.editing
            ? 'Skip'
            : widget.index < categories.length - 1
                ? 'Next'
                : null,
        onTrailing: !widget.editing
            ? () => _advance(categories.length)
            : widget.index < categories.length - 1
                ? () => _leave(categories.length)
                : null,
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: widget.editing
                ? widget.index < categories.length - 1
                    ? 'Save ${picked.length} and next'
                    : 'Save ${picked.length} on your profile'
                : picked.isEmpty
                    ? 'Pick at least one'
                    : 'Continue with ${picked.length}',
            busy: _saving,
            onPressed: !widget.editing && picked.isEmpty
                ? null
                : () => _next(category, current, categories.length),
          ),
          // Only where we asked. Nothing was found and nothing was written, so
          // leaving with nothing has to be one tap rather than a dead end.
          if (asking && !widget.editing)
            TextActionButton(
              label: 'Skip ${category.label.toLowerCase()}',
              dim: true,
              onPressed: () => _advance(categories.length),
            ),
        ],
      ),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (!widget.editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 12),
                  child: AppProgressBar(
                    value: (widget.index + 1) / categories.length,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.titleGutter, 2, Insets.titleGutter, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.fill2,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            category.glyph,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            category.label,
                            style: AppText.title1.copyWith(fontSize: 29),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      widget.editing
                          ? '${picked.length} on your profile. Tap to add or '
                              'drop one.'
                          : asking
                              ? 'Not enough here to say anything true. So we '
                                  'would rather ask.'
                              : 'Pick up to two, and put a photo or video '
                                  'behind any of them.',
                      style: AppText.callout.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              BentoGrid(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 18, Insets.gutter, 0),
                children: [
                  for (final ins in inCategory)
                    _item(
                      (kind: TileKind.insight, key: ins.key),
                      media: media,
                      serverMedia: saved[TileMedia.id(TileKind.insight, ins.key)],
                      size: ins.tileSize,
                      number: ins.displayValue,
                      caption: ins.caption,
                      tone: ins.tone,
                      isTrack: ins.looksLikeTrack,
                    ),
                  if (!asking)
                    for (final a in answered)
                      _item(
                        (kind: TileKind.prompt, key: a.promptKey),
                        media: media,
                        serverMedia:
                            saved[TileMedia.id(TileKind.prompt, a.promptKey)],
                        size: TileSize.wide,
                        prompt: a.question,
                        answer: a.answer,
                        tone: _toneOf(category),
                      ),
                ],
              ),
              for (final prompt in questions)
                _question(
                  prompt,
                  answers: answers,
                  media: media,
                  saved: saved,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.titleGutter, 16, Insets.titleGutter, 0),
                child: Text(
                  widget.editing
                      ? 'Dropping a tile takes it off your profile. It stays here, '
                          'and you can put it back any time.'
                      : 'Nothing here is public until you pick it. Anything left '
                          'unpicked never appears on your profile, but still '
                          'informs matching.',
                  style: AppText.caption,
                ),
              ),
            ],
          ),
          if (_capNote case final note?)
            Positioned(
              left: 26,
              right: 26,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1116),
                  borderRadius: BorderRadius.circular(Radii.row),
                  border: Border.all(color: AppColors.glassEdge),
                ),
                child: Text(
                  note,
                  textAlign: TextAlign.center,
                  style: AppText.footnote.copyWith(color: AppColors.label),
                ),
              ),
            ),
        ],
      ),
    );
  }

  BentoItem _item(
    _Choice choice, {
    required TileMedia media,
    required MediaAsset? serverMedia,
    required TileSize size,
    required String tone,
    String? number,
    String? caption,
    String? prompt,
    String? answer,
    bool isTrack = false,
  }) {
    final picked = _picked!;
    final behind = media.resolve(choice.kind, choice.key, serverMedia);
    return BentoItem(
      size: size,
      child: InsightTile(
        size: size,
        number: number,
        caption: caption,
        prompt: prompt,
        answer: answer,
        tone: tone,
        isTrack: isTrack,
        mediaUrl: behind?.stillUrl,
        videoUrl: behind?.videoUrl,
        isLivePhoto: behind?.kind == MediaKind.livePhoto,
        mediaBusy: media.isBusy(choice.kind, choice.key),
        // Nothing is dimmed: every tile keeps a live camera, and a faded one
        // would read as switched off.
        selectable: true,
        selected: picked.contains(choice),
        onTap: () => _toggle(choice),
        onMedia: () => _chooseMedia(choice, hasMedia: behind != null),
      ),
    );
  }

  Widget _question(
    Prompt prompt, {
    required List<PromptAnswer> answers,
    required TileMedia media,
    required Map<String, MediaAsset> saved,
  }) {
    final choice = (kind: TileKind.prompt, key: prompt.key);
    return _QuestionRow(
      prompt: prompt,
      answer: answers.where((a) => a.promptKey == prompt.key).firstOrNull,
      picked: _picked!.contains(choice),
      behind: media.resolve(
        choice.kind,
        choice.key,
        saved[TileMedia.id(choice.kind, choice.key)],
      ),
      onOpen: () => _ask(prompt),
      onToggle: () => _toggle(choice),
    );
  }

  /// Opens one question, and ticks what comes back onto the profile. Answering
  /// is choosing: they wrote it to be read.
  Future<void> _ask(Prompt prompt) async {
    final answers = ref.read(promptBankProvider).valueOrNull?.answers;
    final existing =
        answers?.where((a) => a.promptKey == prompt.key).firstOrNull;
    final saved = await showAnswerSheet(
      context,
      prompt: prompt,
      existing: existing,
    );
    if (!saved || !mounted) return;
    final choice = (kind: TileKind.prompt, key: prompt.key);
    if (_picked!.contains(choice)) return;
    _toggle(choice);
  }

  /// The sheet behind the camera on a tile.
  Future<void> _chooseMedia(_Choice choice, {required bool hasMedia}) async {
    final answer = choice.kind == TileKind.prompt;
    final taken = await showAppActionSheet(
      context,
      title: 'Put something behind this',
      message: answer
          ? 'It sits under your answer, on your profile only if this answer '
              'is picked.'
          : 'It sits under the number, on your profile only if this insight '
              'is picked.',
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
      await controller.clear(choice.kind, choice.key, onError: onError);
      return;
    }
    await controller.attach(
      choice.kind,
      choice.key,
      TileMediaSource.values[taken],
      onError: onError,
    );
  }

  /// An answer tile takes its category's colour, as a derived tile would.
  String _toneOf(TileCategory category) => ProfileTile(
        kind: TileKind.prompt,
        key: '',
        category: category,
      ).tone;
}

/// One question on a thin category's screen: what it asks, what they wrote,
/// and whether it is on the profile.
///
/// A question is a row, never a tile. A tile is something we worked out; this
/// is something they said, and the two must not be told apart only by their
/// words.
class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.prompt,
    required this.answer,
    required this.picked,
    required this.behind,
    required this.onOpen,
    required this.onToggle,
  });

  final Prompt prompt;
  final PromptAnswer? answer;
  final bool picked;
  final MediaAsset? behind;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final written = answer;
    final media = behind;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 10),
      child: Pressable(
        onTap: onOpen,
        semanticLabel: written == null
            ? 'Answer: ${prompt.text}'
            : 'Change your answer to ${prompt.text}',
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: AppColors.row,
            borderRadius: BorderRadius.circular(Radii.row),
            border: Border.all(
              color: picked ? AppColors.ok : AppColors.glassEdge,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt.text,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                      ),
                    ),
                    if (written != null) ...[
                      const SizedBox(height: 4),
                      Text(written.answer, style: AppText.caption),
                    ],
                    if (media != null) ...[
                      const SizedBox(height: 8),
                      _behindChip(media),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (written == null)
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.label3,
                )
              else
                Pressable(
                  onTap: onToggle,
                  semanticLabel: picked
                      ? 'Take this answer off your profile'
                      : 'Put this answer on your profile',
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      picked
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 22,
                      color: picked ? AppColors.ok : AppColors.label3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _behindChip(MediaAsset media) {
    final label = switch (media.kind) {
      MediaKind.video => 'Video attached',
      MediaKind.livePhoto => 'Live photo attached',
      _ => 'Photo attached',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.fill2,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_camera_back_outlined,
            size: 13,
            color: AppColors.label2,
          ),
          const SizedBox(width: 5),
          Text(label, style: AppText.caption.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}
